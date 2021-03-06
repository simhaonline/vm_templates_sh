#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

## WITHOUT availability of netcat or ssh/scp on system:
##  (host) simple http server for files: python -m http.server {port}
##  (client) tools:
##    [curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file

set -x
DEVX=${DEVX:-sda}

#vgremove -v vg0 ; pvremove -v /dev/${DEVX}3  # for leftover LVM vols
#zpool destroy ospool0
#zpool labelclear ${DEVX}[x] # for leftover ZFS pools

parttbl_bkup() {
  TOOL=${1:-sgdisk}
  
  echo "Backing up partition table" ; sleep 3
  case $TOOL in
    'sfdisk') sfdisk --dump /dev/${DEVX} > parttbl_${DEVX}.dump ;
      echo "to restore: sfdisk /dev/${DEVX} < parttbl_${DEVX}.dump" ;;
    *) sgdisk --backup parttbl_${DEVX}.bak /dev/${DEVX} ;
      echo "to restore: sgdisk --load-backup parttbl_${DEVX}.bak /dev/${DEVX}" ;;
  esac
}

_sgdisk_vmpartzfs() {
  GRP_NM=${1:-vg0}
  
  sgdisk --zap --clear --mbrtogpt /dev/${DEVX} ; sync
  # typecode: f/ BIOS 1M fat|ef02 (bios_boot) ; f/ EFI 200M efi|ef00 (ESP)
  sgdisk --new 1:1M:+1M --typecode 1:ef02 --change-name 1:"bios_boot" \
    /dev/${DEVX}
  sgdisk --new 2:0:+200M --typecode 2:ef00 --change-name 2:"ESP" /dev/${DEVX}
  
  sgdisk --new 3:0:+1G --typecode 3:8300 --change-name 3:"${GRP_NM}-osBoot" /dev/${DEVX}
  sgdisk --new 4:0:+4G --typecode 4:8200 --change-name 4:"${GRP_NM}-osSwap" /dev/${DEVX}
  sgdisk --new 5:0:+0G --typecode 5:BF00 --change-name 5:"${GRP_NM}-osPool" /dev/${DEVX}
  
  sync ; sgdisk --print /dev/${DEVX} ; sgdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  DEV_BOOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osBoot" | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
  sleep 3 ; yes | mkfs.ext2 -L "${GRP_NM}-osBoot" ${DEV_BOOT}
}
_sfdisk_vmpartzfs() {
  GRP_NM=${1:-vg0}
  
  sfdisk --delete --wipe always /dev/${DEVX} ; sync
  echo -n 'label: gpt' | sfdisk /dev/${DEVX}
  # [s]fdisk type(s) (fdisk /dev/sdX; l):
  # shortcut | MBR | GPT
  #          |  4  | 21686148-6449-6E6F-744E-656564454649 (BIOS boot)
  #  U(EFI)  | EF  | C12A7328-F81F-11D2-BA4B-00A0C93EC93B
  #  Linux swap | 82 | 0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
  #  L(inux) default | 83 | 0FC63DAF-8483-4772-8E79-3D69D8477DE4
  echo -n start=1MiB,size=1MiB,bootable,type=21686148-6449-6E6F-744E-656564454649,name=bios_boot | sfdisk -N 1 /dev/${DEVX}
  echo -n size=200MiB,bootable,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B,name=ESP | sfdisk -N 2 \
    /dev/${DEVX}
  
  echo -n size=1GiB,type=516E7CB6-6ECF-11D6-8FF8-00022D09712B,name="${GRP_NM}-osBoot" | sfdisk -N 3 /dev/${DEVX}
  echo -n size=4GiB,type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F,name="${GRP_NM}-osSwap" | sfdisk -N 4 /dev/${DEVX}
  echo -n type=516E7CB6-6ECF-11D6-8FF8-00022D09712B,name="${GRP_NM}-osPool" | sfdisk -N 5 /dev/${DEVX}
  
  sync ; sfdisk --list /dev/${DEVX} ; sleep 3 ; sfdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  DEV_BOOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osBoot" | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
  sleep 3 ; yes | mkfs.ext2 -L "${GRP_NM}-osBoot" ${DEV_BOOT}
}
_parted_vmpartzfs() {
  GRP_NM=${1:-vg0}
  
  parted --script /dev/${DEVX} mklabel gpt
  DIFF=1 ; END='-0'
  # /dev/${DEVX}: f/ BIOS 1M none (bios_boot) ; f/ EFI 200M fat32 (ESP)
  END=$(( 1 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary $DIFF $END name 1 bios_boot
  DIFF=$END ; END=$(( 200 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary fat32 $DIFF $END name 2 ESP
  
  DIFF=$END ; END=$(( 1 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary $DIFF $END name 3 ${GRP_NM}-osBoot
  DIFF=$END ; END=$(( 4 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 4 ${GRP_NM}-osSwap
  DIFF=$END ; END=100%
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary $DIFF $END name 5 ${GRP_NM}-osPool
  
  parted -s /dev/${DEVX} set 1 bios_grub on
  parted -s /dev/${DEVX} set 2 esp on
  
  sync ; parted -s /dev/${DEVX} unit GiB print ; sleep 3
  parted -s /dev/${DEVX} align-check optimal 1 ; sleep 3
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  DEV_BOOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osBoot" | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
  sleep 3 ; yes | mkfs.ext2 -L "${GRP_NM}-osBoot" ${DEV_BOOT}
}

_sgdisk_vmpartlvm() {
  PV_NM=${1:-pvol0}
  
  sgdisk --zap --clear --mbrtogpt /dev/${DEVX} ; sync
  # typecode: f/ BIOS 1M fat|ef02 (bios_boot) ; f/ EFI 200M efi|ef00 (ESP)
  sgdisk --new 1:1M:+1M --typecode 1:ef02 --change-name 1:"bios_boot" \
    /dev/${DEVX}
  sgdisk --new 2:0:+200M --typecode 2:ef00 --change-name 2:"ESP" /dev/${DEVX}
  
  sgdisk --new 3:0:+0G --typecode 3:8e00 --change-name 3:"${PV_NM}" /dev/${DEVX}
  
  sync ; sgdisk --print /dev/${DEVX} ; sgdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary
  #DEV_ESP=$(blkid | grep -e ESP | cut -d: -f1)
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}
_sfdisk_vmpartlvm() {
  PV_NM=${1:-pvol0}
  
  sfdisk --delete --wipe always /dev/${DEVX} ; sync
  echo -n 'label: gpt' | sfdisk /dev/${DEVX}
  # [s]fdisk type(s) (fdisk /dev/sdX; l):
  # shortcut | MBR | GPT
  #          |  4  | 21686148-6449-6E6F-744E-656564454649 (BIOS boot)
  #  U(EFI)  | EF  | C12A7328-F81F-11D2-BA4B-00A0C93EC93B
  #  L(inux) default | 83 | 0FC63DAF-8483-4772-8E79-3D69D8477DE4
  echo -n start=1MiB,size=1MiB,bootable,type=21686148-6449-6E6F-744E-656564454649,name=bios_boot | sfdisk -N 1 /dev/${DEVX}
  echo -n size=200MiB,bootable,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B,name=ESP | sfdisk -N 2 \
    /dev/${DEVX}
  
  echo -n name=${PV_NM} | sfdisk -N 3 /dev/${DEVX}
  
  sync ; sfdisk --list /dev/${DEVX} ; sleep 3 ; sfdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}
_parted_vmpartlvm() {
  PV_NM=${1:-pvol0}
  
  parted --script /dev/${DEVX} mklabel gpt
  DIFF=1 ; END='-0'
  # /dev/${DEVX}: f/ BIOS 1M none (bios_boot) ; f/ EFI 200M fat32 (ESP)
  END=$(( 1 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary $DIFF $END name 1 bios_boot
  DIFF=$END ; END=$(( 200 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary fat32 $DIFF $END name 2 ESP
  
  DIFF=$END ; END=100%
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 3 ${PV_NM}
  
  parted -s /dev/${DEVX} set 1 bios_grub on
  parted -s /dev/${DEVX} set 2 esp on
  
  sync ; parted -s /dev/${DEVX} unit GiB print ; sleep 3
  parted -s /dev/${DEVX} align-check optimal 1 ; sleep 3
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}


_sgdisk_vmpartstd() {
  GRP_NM=${1:-vg0}
  
  sgdisk --zap --clear --mbrtogpt /dev/${DEVX} ; sync
  # typecode: f/ BIOS 1M fat|ef02 (bios_boot) ; f/ EFI 200M efi|ef00 (ESP)
  sgdisk --new 1:1M:+1M --typecode 1:ef02 --change-name 1:"bios_boot" \
    /dev/${DEVX}
  sgdisk --new 2:0:+200M --typecode 2:ef00 --change-name 2:"ESP" /dev/${DEVX}
  
  sgdisk --new 3:0:+4G --typecode 3:8200 --change-name 3:"${GRP_NM}-osSwap" /dev/${DEVX}
  sgdisk --new 4:0:+11776M --typecode 4:8300 --change-name 4:"${GRP_NM}-osRoot" /dev/${DEVX}
  sgdisk --new 5:0:+6G --typecode 5:8300 --change-name 5:"${GRP_NM}-osVar" /dev/${DEVX}
  sgdisk --new 6:0:+0G --typecode 6:8300 --change-name 6:"${GRP_NM}-osHome" /dev/${DEVX}
  
  sync ; sgdisk --print /dev/${DEVX} ; sgdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}
_sfdisk_vmpartstd() {
  GRP_NM=${1:-vg0}
  
  sfdisk --delete --wipe always /dev/${DEVX} ; sync
  echo -n 'label: gpt' | sfdisk /dev/${DEVX}
  # [s]fdisk type(s) (fdisk /dev/sdX; l):
  # shortcut | MBR | GPT
  #          |  4  | 21686148-6449-6E6F-744E-656564454649 (BIOS boot)
  #  U(EFI)  | EF  | C12A7328-F81F-11D2-BA4B-00A0C93EC93B
  #  Linux swap | 82 | 0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
  #  L(inux) default | 83 | 0FC63DAF-8483-4772-8E79-3D69D8477DE4
  echo -n start=1MiB,size=1MiB,bootable,type=21686148-6449-6E6F-744E-656564454649,name=bios_boot | sfdisk -N 1 /dev/${DEVX}
  echo -n size=200MiB,bootable,type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B,name=ESP | sfdisk -N 2 \
    /dev/${DEVX}
  
  echo -n size=4GiB,type=0657FD6D-A4AB-43C4-84E5-0933C84B4F4F,name="${GRP_NM}-osSwap" | sfdisk -N 3 /dev/${DEVX}
  echo -n size=11776MiB,name="${GRP_NM}-osRoot" | sfdisk -N 4 /dev/${DEVX}
  echo -n size=6GiB,name="${GRP_NM}-osVar" | sfdisk -N 5 /dev/${DEVX}
  echo -n name="${GRP_NM}-osHome" | sfdisk -N 6 /dev/${DEVX}
  
  sync ; sfdisk --list /dev/${DEVX} ; sleep 3 ; sfdisk --verify /dev/${DEVX}
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}
_parted_vmpartstd() {
  GRP_NM=${1:-vg0}
  
  parted --script /dev/${DEVX} mklabel gpt
  DIFF=1 ; END='-0'
  # /dev/${DEVX}: f/ BIOS 1M none (bios_boot) ; f/ EFI 200M fat32 (ESP)
  END=$(( 1 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary $DIFF $END name 1 bios_boot
  DIFF=$END ; END=$(( 200 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary fat32 $DIFF $END name 2 ESP
  
  DIFF=$END ; END=$(( 4 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 3 ${GRP_NM}-osSwap
  DIFF=$END ; END=$(( 11776 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 4 ${GRP_NM}-osRoot
  DIFF=$END ; END=$(( 6 * 1024 + $DIFF ))
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 5 ${GRP_NM}-osVar
  DIFF=$END ; END=100%
  parted -s -a optimal /dev/${DEVX} unit MiB \
    mkpart primary ext2 $DIFF $END name 6 ${GRP_NM}-osHome
  
  parted -s /dev/${DEVX} set 1 bios_grub on
  parted -s /dev/${DEVX} set 2 esp on
  
  sync ; parted -s /dev/${DEVX} unit GiB print ; sleep 3
  parted -s /dev/${DEVX} align-check optimal 1 ; sleep 3
  sleep 3 ; partprobe --summary
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  sleep 3 ; yes | mkfs.fat -n ESP -F 32 ${DEV_ESP} ; sleep 3
}


part_vmdisk() {
  TOOL=${1:-sgdisk} ; VOL_MGR=${2:-lvm} ; GRP_NM=${3:-vg0} ; PV_NM=${4:-pvol0}
  
  echo "Partitioning disk" ; sleep 3
  if [ "${VOL_MGR}" = "zfs" ] ; then
    case $TOOL in
      'sfdisk') _sfdisk_vmpartzfs $GRP_NM ;;
      'parted') _parted_vmpartzfs $GRP_NM ;;
      *) _sgdisk_vmpartzfs $GRP_NM ;;
    esac ;
  elif [ "${VOL_MGR}" = "lvm" ] ; then
    case $TOOL in
      'sfdisk') _sfdisk_vmpartlvm ${PV_NM} ;;
      'parted') _parted_vmpartlvm ${PV_NM} ;;
      *) _sgdisk_vmpartlvm ${PV_NM} ;;
    esac ;
  else
    case $TOOL in
      'sfdisk') _sfdisk_vmpartstd $GRP_NM ;;
      'parted') _parted_vmpartstd $GRP_NM ;;
      *) _sgdisk_vmpartstd $GRP_NM ;;
    esac ;
  fi
}

zfspart_create() {
  ZPARTNM_ZPOOLNM=${1:-vg0-osPool:ospool0}
  modprobe zfs
  lsmod | grep -e zfs ; sleep 5
  
  zpartnm=$(echo $ZPARTNM_ZPOOLNM | cut -d: -f1)
  zpoolnm=$(echo $ZPARTNM_ZPOOLNM | cut -d: -f2)
  idx=$(lsblk -nlpo name,label,partlabel | sed -n "/${zpartnm}/ s|.*[sv]da\([0-9]*\).*|\1|p")
  
  zpool destroy $zpoolnm ;
  zpool labelclear -f /dev/${DEVX}${idx} ;
  
  #zpool create -R /mnt -O mountpoint=none -o ashift=12 -O compress=lz4 \
  zpool create -R /mnt -O mountpoint=/ -o ashift=12 -O compress=lz4 \
    -O relatime=on -O dedup=off -O canmount=off -O normalization=formD \
    -O dnodesize=auto $zpoolnm /dev/${DEVX}${idx}
  zfs create -o mountpoint=none -o canmount=off $zpoolnm/ROOT
  zfs create -o canmount=noauto -o mountpoint=/ $zpoolnm/ROOT/default
  #zfs create -o mountpoint=/ $zpoolnm/ROOT/default
  zfs mount $zpoolnm/ROOT/default
  
  zfs create -o mountpoint=/tmp -o com.sun:auto-snapshot=false $zpoolnm/tmp
  zfs create -o mountpoint=/usr -o canmount=off $zpoolnm/usr
  zfs create $zpoolnm/usr/local
  zfs create -o mountpoint=/home -o canmount=off $zpoolnm/home
  zfs create -o mountpoint=/root $zpoolnm/root
  zfs create -o mountpoint=/var -o canmount=off $zpoolnm/var
  zfs create -o canmount=off $zpoolnm/var/lib
  zfs create -o exec=off -o setuid=off -o acltype=posixacl -o xattr=sa \
    $zpoolnm/var/log
  zfs create $zpoolnm/var/spool
  zfs create -o com.sun:auto-snapshot=false $zpoolnm/var/cache
  zfs create -o setuid=off -o com.sun:auto-snapshot=false $zpoolnm/var/tmp
  zfs create -o atime=on $zpoolnm/var/mail
  zfs create -o mountpoint=/opt $zpoolnm/opt
  
  zfs set quota=8G $zpoolnm/home
  zfs set quota=6G $zpoolnm/var
  zfs set quota=2G $zpoolnm/tmp
  #zfs set mountpoint=/$zpoolnm $zpoolnm
  
  zpool set bootfs=$zpoolnm/ROOT/default $zpoolnm # ??
  zpool set cachefile=/etc/zfs/zpool.cache $zpoolnm ; sync
  
  zpool export $zpoolnm ; sync ; sleep 3
  zpool import -d /dev/${DEVX}${idx} -R /mnt -N $zpoolnm
  zpool import -R /mnt -N $zpoolnm
  zfs mount $zpoolnm/ROOT/default ; zfs mount -a ; sync
  zpool set cachefile=/etc/zfs/zpool.cache $zpoolnm
  sync ; cat /etc/zfs/zpool.cache ; sleep 3
  mkdir -p /mnt/etc/zfs ; cp /etc/zfs/zpool.cache /mnt/etc/zfs/
  
  zpool list -v ; sleep 3 ; zfs list ; sleep 3
  zfs mount ; sleep 5
}

lvmpv_create() {
  PARTS_NM_SZ=${PARTS_NM_SZ:-osSwap:4G osRoot:11776M osVar:6G osHome:7680M}
  GRP_NM=${1:-vg0} ; PV_NM=${2:-pvol0}
  modprobe dm-mod ; modprobe dm-crypt
  lsmod | grep -e dm_mod -e dm_crypt ; sleep 5
  
  #DEV_PV=$(blkid | grep -e ${PV_NM} | cut -d: -f1)
  DEV_PV=$(lsblk -nlpo name,partlabel | grep -e ${PV_NM} | cut -d' ' -f1)
  pvcreate ${DEV_PV} ; pvs ; sleep 3
  vgcreate ${GRP_NM} ${DEV_PV} ; vgs ; sleep 3
  for nm_sz in ${PARTS_NM_SZ} ; do
    lv_nm=$(echo $nm_sz | cut -d: -f1) ; lv_sz=$(echo $nm_sz | cut -d: -f2) ;
    lvcreate -n $lv_nm -L $lv_sz ${GRP_NM} ;
    if [ "osSwap" = "$lv_nm" ] ; then
      lvchange --contiguous y ${GRP_NM}/osSwap ;
    fi ;
  done
  vgscan ; vgchange -ay ; sleep 3 ; lvs ; sleep 3
}

format_partitions() {
  MKFS_CMD=${MKFS_CMD:-mkfs.ext4}
  PARTS_NM_SZ=${PARTS_NM_SZ:-osSwap:4G osRoot:11776M osVar:6G osHome:7680M}
  VOL_MGR=${1:-lvm} ; GRP_NM=${2:-vg0} ; PV_NM=${3:-pvol0}
  
  echo "Formatting file systems" ; sleep 3
  if [ "${VOL_MGR}" = "zfs" ] ; then
    ZPARTNM_ZPOOLNM=${ZPARTNM_ZPOOLNM:-${GRP_NM}-osPool:ospool0}
    zfspart_create $ZPARTNM_ZPOOLNM ;
    
    DEV_SWAP=$(blkid | grep -e "${GRP_NM}-osSwap" | cut -d: -f1) ;
    yes | mkswap -L "${GRP_NM}-osSwap" ${DEV_SWAP} ;
  else
    if [ "${VOL_MGR}" = "lvm" ] ; then
      lvmpv_create $GRP_NM $PV_NM ;
    fi ;
    for nm_sz in ${PARTS_NM_SZ} ; do
      lv_nm=$(echo $nm_sz | cut -d: -f1) ; lv_sz=$(echo $nm_sz | cut -d: -f2) ;
      #DEV_LV=$(blkid | grep -e "${GRP_NM}-${lv_nm}" | cut -d: -f1) ;
      DEV_LV=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-${lv_nm}" | cut -d' ' -f1) ;
      if [ "osSwap" = "$lv_nm" ] ; then
        yes | mkswap -L "${GRP_NM}-osSwap" ${DEV_LV} ;
      else
        yes | ${MKFS_CMD} -L "${GRP_NM}-${lv_nm}" ${DEV_LV} ;
      fi ;
    done ;
  fi
  sync
}

part_format_vmdisk() {
  MKFS_CMD=${MKFS_CMD:-mkfs.ext4}
  PARTS_NM_SZ=${PARTS_NM_SZ:-osSwap:4G osRoot:11776M osVar:6G osHome:7680M}
  TOOL=${1:-sgdisk} ; VOL_MGR=${2:-lvm} ; GRP_NM=${3:-vg0} ; PV_NM=${4:-pvol0}
  
  part_vmdisk $TOOL $VOL_MGR $GRP_NM $PV_NM
  format_partitions $VOL_MGR $GRP_NM $PV_NM
}

mount_filesystems() {
  GRP_NM=${1:-vg0}
  
  DEV_BOOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osBoot" | cut -d' ' -f1)
  DEV_ROOT=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osRoot" | cut -d' ' -f1)
  DEV_VAR=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osVar" | cut -d' ' -f1)
  DEV_HOME=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osHome" | cut -d' ' -f1)
  DEV_SWAP=$(lsblk -nlpo name,label,partlabel | grep -e "${GRP_NM}-osSwap" | cut -d' ' -f1)
  
  echo "Mounting file systems" ; sync ; sleep 3
  mkdir -p /mnt ; mount ${DEV_ROOT} /mnt
  mkdir -p /mnt/root /mnt/var /mnt/home
  mount ${DEV_VAR} /mnt/var ; mount ${DEV_HOME} /mnt/home
  zfs mount -a ; mkdir -p /mnt/etc/zfs
  swapon ${DEV_SWAP}
  
  mkdir -p /mnt/boot ; mount ${DEV_BOOT} /mnt/boot
  #DEV_ESP=$(blkid | grep -e ESP | cut -d: -f1)
  DEV_ESP=$(lsblk -nlpo name,partlabel | grep -e ESP | cut -d' ' -f1)
  mkdir -p /mnt/boot/efi ; mount ${DEV_ESP} /mnt/boot/efi
  sync ; lsblk -l ; sleep 3
}

#----------------------------------------
$@
