#!/bin/sh -x

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'
# perl -e 'print crypt("password", "\$6\$16CHARACTERSSALT") . "\n"'

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

## WITHOUT availability of netcat or ssh/scp on system:
##  (host) simple http server for files: python -m http.server {port}
##  (client) tools:
##    [curl | wget | aria2c | fetch | ftp] http://{host}:{port}/{path}/file

# usage: sh vminstall_chroot.sh [oshost [GUEST]]
#   (default) sh vminstall_chroot.sh [freebsd [freebsd-Release-zfs]]

STORAGE_DIR=${STORAGE_DIR:-`dirname $0`}
ISOS_PARDIR=${ISOS_PARDIR:-/mnt/Data0/distros}

cp -R $HOME/.ssh/publish_krls init/common/skel/_ssh/

freebsd() {
  GUEST=${1:-freebsd-Release-zfs}
  ISO_PATH=${ISO_PATH:-`find ${ISOS_PARDIR}/freebsd -name 'FreeBSD-*-amd64-disc1.iso' | tail -n1`}
  #IMAGE_OPTS=${IMAGE_OPTS:-"-cdrom ${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  (cd ${ISOS_PARDIR}/freebsd ; sha256sum --ignore-missing -c CHECKSUM.SHA256-FreeBSD-*-RELEASE-amd64) ; sleep 5
  
  ##!! (chrootsh) navigate to single user: 2
  ##!! if late, Live CD -> root/-
  
  #mdmfs -s 100m md1 /tmp ; mdmfs -s 100m md2 /mnt ; cd /tmp ; ifconfig
  #dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.{ifdev} {ifdev}
  
  ## (FreeBSD) install via chroot
  ## NOTE, transfer [dir(s) | file(s)]: init/common, init/freebsd
  
  #set DEVX=da0 ; gpart show -l
  #sh init/common/gpart_setup_vmfreebsd.sh part_format_vmdisk [std | zfs]
  #sh init/common/gpart_setup_vmfreebsd.sh mount_filesystems
  
  #sh init/freebsd/zfs-install.sh [hostname [$CRYPTED_PASSWD]]
}

devuan() {
  GUEST=${1:-devuan-Stable-lvm}
  ISO_PATH=${ISO_PATH:-`find ${ISOS_PARDIR}/devuan-live -name 'devuan_*_amd64_desktop-live.iso' | tail -n1`}
  #IMAGE_OPTS=${IMAGE_OPTS:-"-cdrom ${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  (cd ${ISOS_PARDIR}/devuan-live ; sha256sum --ignore-missing -c SHA256SUMS.txt) ; sleep 5
  
  ##!! login user/passwd: devuan/devuan
  
  #sudo su ; export MIRRORHOST=deb.devuan.org/merged ; . /etc/os-release
  #mount -o remount,size=1G /run/live/overlay ; df -h ; sleep 5
  #apt-get --yes update --allow-releaseinfo-change
  #apt-get --yes install lvm2 gdisk
  
  #------------ if using ZFS ---------------
  #apt-get --yes install --no-install-recommends linux-headers-$(uname -r)
  
  #echo "deb http://$MIRRORHOST $VERSION_CODENAME-backports main" >> /etc/apt/sources.list
  #sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list
  #apt-get --yes update
  #apt-get --yes install -t $VERSION_CODENAME-backports --no-install-recommends zfs-dkms zfsutils-linux
  
  #modprobe zfs ; sleep 5 ; zpool version
  #-----------------------------------------
}

voidlinux() {
  GUEST=${1:-voidlinux-Rolling-lvm}
  #ISO_PATH=${ISO_PATH:-`find ${ISOS_PARDIR}/voidlinux -name 'voidlinux-live-x86_64-*.iso' | tail -n1`}
  ## change for ZFS already on iso
  ISO_PATH=${ISO_PATH:-`find ${ISOS_PARDIR}/voidlinux -name 'Trident-*-x86_64.iso' | tail -n1`}
  #IMAGE_OPTS=${IMAGE_OPTS:-"-cdrom ${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  (cd ${ISOS_PARDIR}/voidlinux ; sha256sum --ignore-missing -c sha256sums_trident.txt) ; sleep 5
  
  ##!! login user/passwd: anon/voidlinux
  
  #sv down sshd ; bash
  #export MIRRORHOST=mirror.clarkson.edu/voidlinux
  #yes | xbps-install -Sy -R http://${MIRRORHOST}/current -u xbps ; sleep 3
  #yes | xbps-install -Sy -R http://${MIRRORHOST}/current netcat wget parted gptfdisk lvm2
  
  #------------ if using ZFS ---------------
  #modprobe zfs ; sleep 5 ; zpool version
  #-----------------------------------------
}

artix() {
  GUEST=${1:-artix-Rolling-lvm}
  ISO_PATH=${ISO_PATH:-`find ${ISOS_PARDIR}/artix -name 'artix-*-openrc-*.iso' | tail -n1`}
  #IMAGE_OPTS=${IMAGE_OPTS:-"-cdrom ${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  (cd ${ISOS_PARDIR}/artix ; sha256sum --ignore-missing -c sha256sums) ; sleep 5
  
  ##!! login user/passwd: artix/artix 
  
  #sudo su
  #mount -o remount,size=1G /run/artix/cowspace ; df -h ; sleep 5
  #pacman-key --init ; pacman-key --populate artix
  #pacman -Sy artix-keyring gnu-netcat parted gptfdisk lvm2
    
  #------------ if using ZFS ---------------
  ## NOTE, transfer archzfs config file: init/archlinux/repo_archzfs.cfg
  #cat init/archlinux/repo_archzfs.cfg >> /etc/pacman.conf
  #curl -o /tmp/archzfs.gpg http://archzfs.com/archzfs.gpg
  #pacman-key --add /tmp/archzfs.gpg ; pacman-key --lsign-key F75D9D76
  
  #pacman -Sy zfs-utils
  
  #pacman -Sy zfs-dkms
  
  #modprobe zfs ; sleep 5 ; zpool version
  #-----------------------------------------
}

alpine() {
  GUEST=${1:-alpine-Stable-lvm}
  ISO_PATH=${ISO_PATH:-`find ${ISOS_PARDIR}/alpine -name 'alpine-extended-*-x86_64.iso' | tail -n1`}
  #IMAGE_OPTS=${IMAGE_OPTS:-"-cdrom ${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  (cd ${ISOS_PARDIR}/alpine ; sha256sum --ignore-missing -c alpine-extended-*-x86_64.iso.sha256) ; sleep 5
  
  ##!! login user/passwd: root/-
  
  #ifconfig ; ifconfig {ifdev} up ; udhcpc -i {ifdev} ; cd /tmp
  
  #service sshd stop
  #export MIRRORHOST=mirror.math.princeton.edu/pub/alpinelinux ; . /etc/os-release
  #echo http://${MIRRORHOST}/v$(cat /etc/alpine-release | cut -d. -f1-2)/main >> /etc/apk/repositories
  #apk update
  #apk add e2fsprogs dosfstools sgdisk lvm2 util-linux multipath-tools
  #setup-udev
  
  #------------ if using ZFS ---------------
  #apk add zfs
  
  #modprobe zfs ; sleep 5 ; zpool version
  #-----------------------------------------
}


debian() {
  GUEST=${1:-debian-Stable-lvm}
  ISO_PATH=${ISO_PATH:-`find ${ISOS_PARDIR}/debian-live -name 'debian-live-*-amd64*.iso' | tail -n1`}
  #IMAGE_OPTS=${IMAGE_OPTS:-"-cdrom ${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  (cd ${ISOS_PARDIR}/debian-live ; sha256sum --ignore-missing -c SHA256SUMS) ; sleep 5
  
  ##!! login user/passwd: user/live
  
  #sudo su ; export MIRRORHOST=deb.debian.org/debian ; . /etc/os-release
  #mount -o remount,size=1G /run/live/overlay ; df -h ; sleep 5
  #apt-get --yes update --allow-releaseinfo-change
  #apt-get --yes install lvm2 gdisk
  #apt-get --yes install --no-install-recommends linux-headers-$(uname -r)
  
  #------------ if using ZFS ---------------
  #echo "deb http://$MIRRORHOST $VERSION_CODENAME-backports main" >> /etc/apt/sources.list
  #sed -i '/main.*$/ s|main.*$|main contrib non-free|' /etc/apt/sources.list
  #apt-get --yes update
  #apt-get --yes install -t $VERSION_CODENAME-backports --no-install-recommends zfs-dkms zfsutils-linux
  
  #modprobe zfs ; sleep 5 ; zpool version
  #-----------------------------------------
}

archlinux() {
  GUEST=${1:-archlinux-Rolling-lvm}
  ISO_PATH=${ISO_PATH:-`find ${ISOS_PARDIR}/archlinux -name 'archlinux-*.iso' | tail -n1`}
  #IMAGE_OPTS=${IMAGE_OPTS:-"-cdrom ${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  (cd ${ISOS_PARDIR}/archlinux ; sha1sum --ignore-missing -c sha1sums.txt) ; sleep 5
  
  ##!! login user/passwd: -/- 
  
  #mount -o remount,size=1G /run/archiso/cowspace ; df -h ; sleep 5
  #pacman-key --init ; pacman-key --populate archlinux
  #pacman -Sy archlinux-keyring ; pacman -Sy
  
  #------------ if using ZFS ---------------
  ## NOTE, transfer archzfs config file: init/archlinux/repo_archzfs.cfg
  #cat init/archlinux/repo_archzfs.cfg >> /etc/pacman.conf
  #curl -o /tmp/archzfs.gpg http://archzfs.com/archzfs.gpg
  #pacman-key --add /tmp/archzfs.gpg ; pacman-key --lsign-key F75D9D76
  
  #pacman -Sy zfs-utils
  
  #pacman -Sy zfs-dkms
  ##--- or retrieve archived zfs-linux package instead of zfs-dkms ---
  ## Note, xfer archived zfs-linux package matching kernel (uname -r)
  ## example kernelver -> 5.7.11-arch1-1 becomes 5.7.11.arch1.1-1
  ## curl -o /tmp/zfs-linux.pkg.tar.zst 'http://mirror.sum7.eu/archlinux/archzfs/archive_archzfs/zfs-linux-<ver>_<kernelver>-x86_64.pkg.tar.zst'
  ## pacman -U /tmp/zfs-linux.pkg.tar.zst
  ##---
  
  #modprobe zfs ; sleep 5 ; zpool version
  #-----------------------------------------
}

opensuse() {
  GUEST=${1:-opensuse-Stable-lvm}
  ISO_PATH=${ISO_PATH:-`find ${ISOS_PARDIR}/opensuse-live -name 'openSUSE-Leap-*-Live-x86_64-*.iso' | tail -n1`}
  #IMAGE_OPTS=${IMAGE_OPTS:-"-cdrom ${ISO_PATH}"}
  INST_SRC_OPTS=${INST_SRC_OPTS:---cdrom="${ISO_PATH}"}
  (cd ${ISOS_PARDIR}/opensuse-live ; sha256sum --ignore-missing -c openSUSE-Leap-*-Live-x86_64-*.iso.sha256) ; sleep 5
  
  ##!! login user/passwd: linux/-
  
  #sudo su ; export MIRRORHOST=download.opensuse.org ; . /etc/os-release
  #zypper --non-interactive refresh
  
  #zypper install ca-certificates-cacert ca-certificates-mozilla ca-certificates efibootmgr lvm2
  #zypper --gpg-auto-import-keys refresh
  #update-ca-certificates
  
  #------------ if using ZFS ---------------
  #zypper --non-interactive install --no-recommends kernel-devel
  #zypper --gpg-auto-import-keys addrepo http://${MIRRORHOST}/repositories/filesystems/openSUSE_Leap_${VERSION_ID}/filesystems.repo
  #zypper --gpg-auto-import-keys refresh
  #zypper --non-interactive install zfs
  
  #modprobe zfs ; sleep 5 ; zpool version
  #-----------------------------------------
}

#----------------------------------------
${@:-freebsd freebsd-Release-zfs}
  
OUT_DIR=${OUT_DIR:-output-vms/${GUEST}}
mkdir -p ${OUT_DIR}
qemu-img create -f qcow2 ${OUT_DIR}/${GUEST}.qcow2 30720M

#-------------- using virtinst ------------------
#CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
#VBIOS_OPTS=${VBIOS_OPTS:---boot uefi,loader=${STORAGE_DIR}/OVMF/OVMF_CODE.fd}
#
## NOTE, to convert qemu-system args to libvirt domain XML:
## eval "echo \"$(< vminstall_qemu.args)\"" > /tmp/install_qemu.args
## virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/install_qemu.args
#
#virt-install ${CONNECT_OPT} --memory 2048 --vcpus 2 \
#  --controller usb,model=ehci --controller virtio-serial \
#  --console pty,target_type=virtio --graphics vnc,port=-1 \
#  --network network=default,model=virtio-net,mac=RANDOM \
#  --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
#  --disk bus=scsi,path=${OUT_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,format=qcow2 \
#  ${INST_SRC_OPTS} ${VBIOS_OPTS} -n ${GUEST} &
#
#echo "### Once network connected, transfer needed file(s) ###"
#sleep 30 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST}
##sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > ${OUT_DIR}/${GUEST}.xml
#------------------------------------------------

#------------ using qemu-system-* ---------------
QBIOS_OPTS=${QBIOS_OPTS:-"-smbios type=0,uefi=on -bios ${STORAGE_DIR}/OVMF/OVMF_CODE.fd"}
echo "Verify bridge device ($IFCBR) allowed in /etc/qemu/bridge.conf" ; sleep 3
cat /etc/qemu/bridge.conf ; sleep 5
echo "(if needed) Quickly catch boot menu to add kernel boot parameters"
sleep 5

qemu-system-x86_64 -machine accel=kvm:hvf:tcg -smp cpus=2 -m size=2048 \
  -boot order=cdn,menu=on -usb -device usb-tablet \
  -net nic,model=virtio-net-pci,macaddr=52:54:00:`openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||'` \
  ${NET_OPTS:--net bridge,br=virbr0} \
  -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
  -drive file=${OUT_DIR}/${GUEST}.qcow2,format=qcow2,if=none,id=hd0,cache=writeback,discard=unmap \
  ${IMAGE_OPTS} ${QBIOS_OPTS} -name ${GUEST} &

echo "### Once network connected, transfer needed file(s) ###"
#------------------------------------------------

sleep 30


#-----------------------------------------
## package manager tools & config needed to install from existing Linux
  
#debian variants(debian, devuan):
  # (devuan MIRROR: deb.devuan.org/merged)
  # (debian MIRROR: deb.debian.org/debian)
  #  package(s): debootstrap
  
#void linux: (MIRROR: mirror.clarkson.edu/voidlinux)
  ## dnld: http://${MIRROR}/static/xbps-static-latest.x86_64-musl.tar.xz
  #  package(s): xbps-install.static (download xbps-static tarball)
  
#arch linux variants(arch, artix):
  #  package(s): pacman, ? libffi
  ## ----- config pacman.conf & mirrorlist -----
  #mkdir -p /etc/pacman.d
  #curl -s "https://www.archlinux.org/mirrorlist/?country=${LOCALE_COUNTRY:-US}&use_mirror_status=on" | sed -e 's|^#Server|Server|' -e '/^#/d' | tee /etc/pacman.d/mirrorlist-arch
  #(artix only) curl -s "https://gitea.artixlinux.org/packagesA/artix-mirrorlist/raw/branch/master/trunk/mirrorlist" | tee /etc/pacman.d/mirrorlist-artix
  #(artix only) curl -s "https://gitea.artixlinux.org/packagesP/pacman/raw/branch/master/trunk/pacman.conf" | tee /etc/pacman.conf
  #(artix only) cp /etc/pacman.d/mirrorlist-artix /etc/pacman.d/mirrorlist
  #(arch only) cat init/archlinux/etc_pacman.conf-arch >> /etc/pacman.conf
  #(arch only) cp /etc/pacman.d/mirrorlist-arch /etc/pacman.d/mirrorlist
  #pacman-key --init ; pacman-key --populate [artix | archlinux]
  #pacman-key --recv-keys 'arch@eworm.de' ; pacman-key --lsign-key 498E9CEE
  #pacman -Sy [artix | archlinux]-keyring
  
#alpine linux: (MIRROR: mirror.math.princeton.edu/pub/alpinelinux)
  ## dnld: http://${MIRROR}/latest-stable/main/x86_64/apk-tools-static-*.apk
  #  package(s): apk.static (download apk[-tools]-static)
  
#suse variants(opensuse): (MIRROR: download.opensuse.org)
  #  package(s): zypper, ? rinse
  
#----------------------------------------
## (Linux distro) install via chroot
## NOTE, transfer [dir(s) | file(s)]: init/common, init/<variant>

#  export DEVX=sda ; [[sgdisk -p | sfdisk -l] /dev/$DEVX | parted /dev/$DEVX -s unit GiB print]
#  sh init/common/disk_setup_vmlinux.sh part_format_vmdisk [sgdisk | sfdisk | parted] [lvm | zfs] [ .. ]
#  sh init/common/disk_setup_vmlinux.sh mount_filesystems [ .. ]

#  sh init/<variant>/[lvm | zfs]-install.sh [hostname [$CRYPTED_PASSWD]]
#----------------------------------------
