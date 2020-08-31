#!/bin/bash -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

#sh /tmp/disk_setup.sh part_vmdisk sgdisk lvm vg0 pvol0
#sh /tmp/disk_setup.sh format_partitions lvm vg0 pvol0
#sh /tmp/disk_setup.sh mount_filesystems vg0

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), '\$6\$16CHARACTERSSALT'))"
# perl -e "print crypt('password', '\$6\$16CHARACTERSSALT') . \"\n\""

set -x

export DEVX=${DEVX:-sda} ; export GRP_NM=${GRP_NM:-vg0}
export MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/centos}
ADD_VAGRANTUSER=${ADD_VAGRANTUSER:-0} ; BASEARCH=${BASEARCH:-x86_64}

export INIT_HOSTNAME=${1:-centos-boxv0000}
#export PLAIN_PASSWD=${2:-abcd0123}
export CRYPTED_PASSWD=${2:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}

export YUMCMD="yum --setopt=requires_policy=strong --setopt=group_package_types=mandatory"
export DNFCMD="dnf --setopt=install_weak_deps=False"

umount /mnt/boot/efi
DEV_ESP=$(lsblk -nlpo name,label,partlabel | grep -e ESP | cut -d' ' -f1)
yes | mkfs.fat -n ESP ${DEV_ESP}
mount ${DEV_ESP} /mnt/boot/efi

echo "Create /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/media ; chmod 0755 /mnt/media
sh -c 'cat > /mnt/etc/fstab' << EOF
LABEL=${GRP_NM}-osRoot   /           ext4    errors=remount-ro   0   1
LABEL=${GRP_NM}-osVar    /var        ext4    defaults    0   2
LABEL=${GRP_NM}-osHome   /home       ext4    defaults    0   2
LABEL=ESP      /boot/efi   vfat    umask=0077  0   2
LABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

EOF


VERSION_ID=8


echo "Bootstrap base pkgs" ; sleep 3
#wget -O /tmp/bash.rpm http://${MIRROR}/${VERSION_ID}/BaseOS/${BASEARCH}/os/Packages/bash-4.4.19-10.el${VERSION_ID}.${BASEARCH}.rpm
#wget -O /tmp/dnf.rpm http://${MIRROR}/${VERSION_ID}/BaseOS/${BASEARCH}/os/Packages/dnf-4.2.17-7.el8_2.noarch.rpm
#wget -O /tmp/centos-release.rpm http://${MIRROR}/${VERSION_ID}/BaseOS/${BASEARCH}/os/Packages/centos-release-${VERSION_ID}.2-2.2004.0.1.el${VERSION_ID}.${BASEARCH}.rpm
#rpm -v -qip /tmp/centos-release.rpm ; sleep 5
#rpm -v --root /mnt --initdb ; sleep 3
#rpm -v --root /mnt --nodeps -i /tmp/bash.rpm /tmp/dnf.rpm /tmp/centos-release.rpm
${YUMCMD} -y --installroot=/mnt --releasever=${VERSION_ID} install yum dnf centos-release yum-utils dnf-plugins-core
mkdir -p /mnt/etc/yum.repos.d


echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
cp /etc/mtab /mnt/etc/mtab
mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run
mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys
mount --rbind /dev /mnt/dev

mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run
modprobe efivarfs
mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/

## temporarily disable SELinux to allow chpasswd in chroot
#setenforce 0 ; sestatus ; sleep 5

#mkdir -p /mnt/var/empty /mnt/var/lock/subsys /mnt/etc/sysconfig/network-scripts
#cp /etc/sysconfig/network-scripts/ifcfg-$ifdev /mnt/etc/sysconfig/network-scripts/ifcfg-${ifdev}.bak
cp /etc/resolv.conf /mnt/etc/resolv.conf


# LANG=[C|en_US].UTF-8
cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en chroot /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
chown root:root / ; chmod 0755 /

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

#mount -t proc none /proc
##cd /dev ; MAKEDEV generic


echo "Config pkg repo mirror(s)" ; sleep 3
. /etc/os-release
mkdir -p /etc/yum.repos.d
#yum-config-manager --add-repo http://${MIRROR}/$VERSION_ID/os/$BASEARCH
#yum-config-manager --add-repo http://mirrorlist.centos.org/?release=$VERSION_ID&arch=$BASEARCH&repo=os
#yum-config-manager --add-repo http://mirrorlist.centos.org/?release=$VERSION_ID&arch=$BASEARCH&repo=updates
#yum-config-manager --add-repo http://mirrorlist.centos.org/?release=$VERSION_ID&arch=$BASEARCH&repo=extras

#dnf config-manager --add-repo http://${MIRROR}/${VERSION_ID}/BaseOS/${BASEARCH}/os
#dnf config-manager --add-repo http://${MIRROR}/${VERSION_ID}/AppStream/${BASEARCH}/os
#dnf config-manager --add-repo http://${MIRROR}/${VERSION_ID}/extras/${BASEARCH}/os

cat << EOF >> /etc/yum.repos.d/CentOS-Base.repo
[BaseOS]
name=CentOS-${VERSION_ID} - Base
mirrorlist=http://mirrorlist.centos.org/?release=${VERSION_ID}&arch=${BASEARCH}&repo=BaseOS&infra=stock
#baseurl=http://${MIRROR}/${VERSION_ID}/BaseOS/${BASEARCH}/os
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF
cat << EOF >> /etc/yum.repos.d/CentOS-AppStream.repo
[AppStream]
name=CentOS-${VERSION_ID} - AppStream
mirrorlist=http://mirrorlist.centos.org/?release=${VERSION_ID}&arch=${BASEARCH}&repo=AppStream&infra=stock
#baseurl=http://${MIRROR}/${VERSION_ID}/AppStream/${BASEARCH}/os
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF
cat << EOF >> /etc/yum.repos.d/CentOS-Extras.repo
[extras]
name=CentOS-${VERSION_ID} - Extras
mirrorlist=http://mirrorlist.centos.org/?release=${VERSION_ID}&arch=${BASEARCH}&repo=extras&infra=stock
#baseurl=http://${MIRROR}/${VERSION_ID}/extras/${BASEARCH}/os
gpgcheck=1
enabled=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial
EOF

${YUMCMD} -y reinstall yum dnf yum-utils dnf-plugins-core
${YUMCMD} -y install yum dnf yum-utils dnf-plugins-core
${DNFCMD} -y install \${ID}-release epel-release
#${DNFCMD} -y check-update
#cat /etc/yum.repos.d/* ; sleep 5
${DNFCMD} repolist ; sleep 5


echo "Add software package selection(s)" ; sleep 3
#${DNFCMD} -y check-update
${DNFCMD} -y install @core linux-firmware microcode_ctl sudo kbd epel-release openssh-clients openssh-server openssl grub2 grub2-efi-x64 shim efibootmgr kernel lvm2

kver=\$(dnf list --installed kernel | sed -n 's|kernel[a-z0-9._]*[ ]*\([^ ]*\)[ ]*.*$|\1|p' | tail -n1)
echo \$kver ; sleep 5
${DNFCMD} -y install kernel-devel-\$kver.$BASEARCH
# @xfce-desktop
# @^minimal @minimal-environment redhat-lsb-core dracut-tools dracut-config-generic dracut-config-rescue kernel-devel-$(uname -r)


os_ver=\$(sed 's|.* \([0-9]*\.[0-9]*\).*|\1|' /etc/redhat-release | tr . _)

echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us ## ?? error
sed -i '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
echo 'LANG=en_US.UTF-8' >> /etc/locale.conf
locale-gen # en_US en_US.UTF-8

#sh -c 'cat >> /etc/default/locale' << EOF
#LANG=en_US.UTF-8
##LC_ALL=en_US.UTF-8
#LANGUAGE="en_US:en"
#
#EOF


echo "Config time zone & clock" ; sleep 3
rm /etc/localtime
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc --utc


echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}" > /etc/hostname
#sh -c 'cat >> /etc/resolv.conf' << EOF
##search hqdom.local
#nameserver 8.8.8.8
#
#EOF
cat /etc/resolv.conf ; sleep 5
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')
sh -c "cat >> /etc/sysconfig/network-scripts/ifcfg-\$ifdev" << EOF
BOOTPROTO=dhcp
STARTMODE=auto
ONBOOT=yes
DHCP_CLIENT=dhclient

EOF

sh -c "cat >> /etc/sysconfig/network" << EOF
NETWORKING=yes
CRDA_DOMAIN=US
HOSTNAME=${INIT_HOSTNAME}

EOF


echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PLAIN_PASSWD}" | chpasswd
echo -n 'root:${CRYPTED_PASSWD}' | chpasswd -e

DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PLAIN_PASSWD}" | chpasswd
echo -n 'packer:${CRYPTED_PASSWD}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat >> /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /etc/sudoers.d/99_packer


if [ ! "0" = "${ADD_VAGRANTUSER}" ] ; then
DIR_MODE=0750 useradd -m -G wheel -s /bin/bash -c 'Vagrant User' vagrant ;
echo -n "vagrant:vagrant" | chpasswd ;
chown -R vagrant:\$(id -gn vagrant) /home/vagrant ;

#sh -c 'cat > /etc/sudoers.d/99_vagrant' << EOF ;
#Defaults:vagrant !requiretty
#\$(id -un vagrant) ALL=(ALL) NOPASSWD: ALL
#
#EOF
#chmod 0440 /etc/sudoers.d/99_vagrant ;
fi


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%sudo|# %sudo|" /etc/sudoers
#sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
echo '%wheel ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


sh -c 'cat >> /etc/ssh/sshd_config' << EOF
TrustedUserCAKeys /etc/ssh/sshca-id_ed25519.pub
RevokedKeys /etc/ssh/krl.krl
#HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

EOF


echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
grub2-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable
#grub2-install --target=i386-pc --recheck /dev/$DEVX
cp -R /boot/efi/EFI/\${ID}/* /boot/efi/EFI/BOOT/
cp /boot/efi/EFI/BOOT/BOOTX64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI.bak
cp /boot/efi/EFI/BOOT/grubx64.EFI /boot/efi/EFI/BOOT/BOOTX64.EFI

sh -c 'cat >> /etc/default/grub' << EOF
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="\$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=false
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="crashkernel=auto rd.auto consoleblank=0 selinux=1 enforcing=0"
GRUB_CMDLINE_LINUX_DEFAULT=""
GRUB_DISABLE_RECOVERY="false"

EOF

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
#sed -i -e "/GRUB_DEFAULT/ s|=.*$|=saved|" /etc/default/grub
#echo "GRUB_SAVEDEFAULT=true" >> /etc/default/grub
#echo "#GRUB_CMDLINE_LINUX='cryptdevice=/dev/sda2:cryptroot'" >> /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub
sed -i '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset rootdelay=5"|'  \
  /etc/default/grub
grub2-mkconfig -o /boot/efi/EFI/\${ID}/grub.cfg
cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/grub2/grub.cfg
cp -f /boot/efi/EFI/\${ID}/grub.cfg /boot/efi/EFI/BOOT/grub.cfg


echo "Config SELinux" ; sleep 3
touch /.autorelabel
sed -i 's|SELINUX=.*$|SELINUX=permissive|' /etc/sysconfig/selinux
sestatus ; sleep 5

efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/\${ID}/grubx64.efi" -L \${ID}
efibootmgr -c -d /dev/$DEVX -p \$(lsblk -nlpo name,label,partlabel | sed -n '/ESP/ s|.*[sv]da\([0-9]*\).*|\1|p') -l "/EFI/BOOT/BOOTX64.EFI" -L Default
efibootmgr -v ; sleep 3

exit

EOFchroot
# end chroot commands

cp -vR /tmp/init.tar /mnt/root/ ; sleep 5

read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
  sync ; swapoff -va ; umount -vR /mnt ;
  reboot ; #poweroff ;
fi
