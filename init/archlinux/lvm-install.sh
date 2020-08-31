#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "su -c 'sh -xs - arg1 argN'" < script.sh
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo

#sh /tmp/disk_setup.sh part_vmdisk sgdisk lvm vg0 pvol0
#sh /tmp/disk_setup.sh format_partitions lvm vg0 pvol0
#sh /tmp/disk_setup.sh mount_filesystems vg0

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c 'import crypt,getpass ; print(crypt.crypt(getpass.getpass(), "$6$16CHARACTERSSALT"))'
# perl -e 'print crypt("password", "\$6\$16CHARACTERSSALT") . "\n"'

set -x
export DEVX=${DEVX:-sda} ; export GRP_NM=${GRP_NM:-vg0}
ADD_VAGRANTUSER=${ADD_VAGRANTUSER:-0}

export INIT_HOSTNAME=${1:-archlinux-boxv0000}
#export PLAIN_PASSWD=${2:-abcd0123}
export CRYPTED_PASSWD=${2:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}

echo "Create /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/media ; chmod 0755 /mnt/media
echo '' > /mnt/etc/fstab
if [ ! -z $(which genfstab) ] ; then
  #genfstab -t LABEL -p /mnt >> /mnt/etc/fstab ;
  genfstab -t UUID -p /mnt >> /mnt/etc/fstab ;
elif [ ! -z $(which fstabgen) ] ; then
  #fstabgen -t LABEL -p /mnt >> /mnt/etc/fstab ;
  fstabgen -t UUID -p /mnt >> /mnt/etc/fstab ;
else
  cat << EOF > /mnt/etc/fstab ;
LABEL=${GRP_NM}-osRoot   /           ext4    errors=remount-ro   0   1
LABEL=${GRP_NM}-osVar    /var        ext4    defaults    0   2
LABEL=${GRP_NM}-osHome   /home       ext4    defaults    0   2
LABEL=ESP      /boot/efi   vfat    umask=0077  0   2
LABEL=${GRP_NM}-osSwap   none        swap    sw          0   0

proc                            /proc       proc    defaults    0   0
sysfs                           /sys        sysfs   defaults    0   0

EOF
fi

# ip link ; dhcpcd #; iw dev
#if [[ ! -z wlan0 ]] ; then      # wlan_ifc: wlan0, wlp2s0
#    wifi-menu wlan0 ;
#fi


echo "Config pkg repo mirror(s)" ; sleep 3
mkdir -p /mnt/etc/pacman.d /mnt/var/lib/pacman
cp /etc/pacman.conf /mnt/etc/pacman.conf.bak
## fetch cmd: [curl -s | wget -qO -]
#reflector --verbose --country ${LOCALE_COUNTRY:-US} --sort rate --fastest 10 --save /etc/pacman.d/mirrorlist-arch ;
wget -qO - "https://www.archlinux.org/mirrorlist/?country=${LOCALE_COUNTRY:-US}&use_mirror_status=on" | sed -e 's|^#Server|Server|' -e '/^#/d' | tee /mnt/etc/pacman.d/mirrorlist-arch ;
#cp /mnt/etc/pacman.d/mirrorlist-arch /mnt/etc/pacman.d/mirrorlist-arch.bak ;
#rankmirrors -vn 10 /etc/pacman.d/mirrorlist-arch.bak | tee /etc/pacman.d/mirrorlist-arch ;

if [ ! -z $(which pacstrap) ] ; then
  cp /mnt/etc/pacman.d/mirrorlist-arch /mnt/etc/pacman.d/mirrorlist ;
else # elif [ ! -z $(which basestrap) ] ; then
  wget -qO - "https://gitea.artixlinux.org/packagesP/pacman/raw/branch/master/trunk/pacman.conf" | tee /mnt/etc/pacman.conf ;
  wget -qO - "https://gitea.artixlinux.org/packagesA/artix-mirrorlist/raw/branch/master/trunk/mirrorlist" | tee /mnt/etc/pacman.d/mirrorlist-artix ;
  cp /mnt/etc/pacman.d/mirrorlist-artix /mnt/etc/pacman.d/mirrorlist ;
fi
sleep 5 ; cp /mnt/etc/pacman.conf /mnt/etc/pacman.conf.old
for libname in multilib lib32 ; do
  MULTILIB_LINENO=$(grep -n "\[$libname\]" /mnt/etc/pacman.conf | cut -f1 -d:) ;
  sed -i "${MULTILIB_LINENO}s|^#||" /mnt/etc/pacman.conf ;
  MULTILIB_LINENO=$(( $MULTILIB_LINENO + 1 )) ;
  sed -i "${MULTILIB_LINENO}s|^#||" /mnt/etc/pacman.conf ;
done


echo "Bootstrap base pkgs" ; sleep 3
pkg_list="base linux-lts linux-lts-headers intel-ucode amd-ucode linux-firmware dosfstools e2fsprogs xfsprogs reiserfsprogs jfsutils sysfsutils grub efibootmgr usbutils inetutils logrotate which dialog man-db man-pages less perl s-nail texinfo diffutils vi nano sudo"
# ifplugd # wpa_actiond iw wireless_tools
#pacman -Sg base | cut -d' ' -f2 | sed 's|^linux$|linux-lts|g' | pacstrap /mnt -
if [ ! -z $(which pacstrap) ] ; then
  pacstrap /mnt $(pacman -Sqg base | sed 's|^linux$|&-lts|') $pkg_list ;
elif [ ! -z $(which basestrap) ] ; then
  basestrap /mnt $(pacman -Sqg base | sed 's|^linux$|&-lts|') $pkg_list ;
else
  pacman --root /mnt -Sy $pkg_list ;
fi

echo "Prepare chroot (mount --[r]bind devices)" ; sleep 3
if [ ! -z $(which arch-chroot) ] ; then
  CHROOT_CMD=arch-chroot ;
elif [ ! -z $(which artools-chroot) ] ; then
  CHROOT_CMD=artools-chroot ;
else
  CHROOT_CMD=chroot ;
  #cp /etc/mtab /mnt/etc/mtab ;
  mkdir -p /mnt/dev /mnt/proc /mnt/sys /mnt/run ;
  mount --rbind /proc /mnt/proc ; mount --rbind /sys /mnt/sys ;
  mount --rbind /dev /mnt/dev ;
  
  mount --rbind /dev/pts /mnt/dev/pts ; mount --rbind /run /mnt/run ;
  modprobe efivarfs ;
  mount -t efivarfs efivarfs /mnt/sys/firmware/efi/efivars/ ;
fi


cp /etc/resolv.conf /mnt/etc/resolv.conf


# LANG=[C|en_US].UTF-8
cat << EOFchroot | LANG=C.UTF-8 LANGUAGE=en $CHROOT_CMD /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp

unset LC_ALL
export TERM=xterm-color     # xterm | xterm-color
hostname ${INIT_HOSTNAME}

ls /proc ; sleep 5 ; ls /dev ; sleep 5

if [ -f /etc/os-release ] ; then
  . /etc/os-release ;
elif [ -f /usr/lib/os-release ] ; then
  . /usr/lib/os-release ;
fi
cat /etc/pacman.conf ; sleep 5

pacman-key --init
if [ "arch" = "\${ID}" ] ; then
  pacman-key --populate archlinux ;
  pacman-key --recv-keys 'arch@eworm.de' ; pacman-key --lsign-key 498E9CEE ;
  pacman --needed -Sy archlinux-keyring ;
elif [ "artix" = "\${ID}" ] ; then
  pacman-key --populate artix ;
  pacman-key --recv-keys 'arch@eworm.de' ; pacman-key --lsign-key 498E9CEE ;
  pacman --needed -Sy artix-keyring ;
fi
if [ "arch" = "\${ID}" ] ; then
  pacman --noconfirm --needed -S cryptsetup device-mapper mdadm lvm2 dhcpcd openssh ;
elif [ "artix" = "\${ID}" ] ; then
  pacman --noconfirm --needed -S cryptsetup-openrc device-mapper-openrc mdadm-openrc lvm2-openrc dhcpcd-openrc openssh-openrc ;
fi
#pacman --noconfirm --needed -S lxde

echo "Config keyboard ; localization" ; sleep 3
kbd_mode -u ; loadkeys us
sed -i -e '/en_US.UTF-8 UTF-8/ s|^# ||' /etc/locale.gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
locale-gen


echo "Config time zone & clock" ; sleep 3
ln -sf /usr/share/zoneinfo/UTC /etc/localtime
hwclock --systohc --utc


echo "Config hostname ; network" ; sleep 3
echo "${INIT_HOSTNAME}" > /etc/hostname
resolvconf -u   # generates /etc/resolv.conf
cat /etc/resolv.conf ; sleep 5
sed -i '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts

ifdev=\$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')
#mkdir -p /etc/systemd/network
#sh -c 'cat > /etc/systemd/network/80-wired-dhcp.network' << EOF
#[Match]
#Name=en*
#
#[Network]
#DHCP=yes
#EOF


echo "Update services" ; sleep 3
if [ ! -z \$(which systemctl) ] ; then
  ## IP address config options: systemd-networkd, dhcpcd, dhclient, netctl
  #systemctl enable systemd-networkd.service ;
  
  systemctl enable dhcpcd@\${ifdev}.service ; # dhcpcd.service
  
  #systemctl enable dhclient@\${ifdev}.service ;
  #systemctl start dhclient@\${ifdev}.service ;
  
  #cp /etc/netctl/examples/ethernet-dhcp /etc/netctl/basic_dhcp_profile ;
  #systemctl enable netctl-ifplugd@\${ifdev}.service # netctl-auto@\${ifdev}.service ;
  
  systemctl enable sshd.service #; systemctl enable sshd.socket ;
elif [ ! -z \$(which rc-update) ] ; then
  ## IP address config options: dhcpcd, dhclient
  rc-update add dhcpcd default ;
  
  #rc-update add dhclient default ;
  #rc-service dhclient start ;
  
  rc-update add sshd default ;
fi

echo "Set root passwd ; add user" ; sleep 3
#echo -n "root:${PLAIN_PASSWD}" | chpasswd
echo -n 'root:${CRYPTED_PASSWD}' | chpasswd -e

#DIR_MODE=0750 
useradd -g users -m -G wheel -s /bin/bash -c 'Packer User' packer
#echo -n "packer:${PLAIN_PASSWD}" | chpasswd
echo -n 'packer:${CRYPTED_PASSWD}' | chpasswd -e
chown -R packer:\$(id -gn packer) /home/packer

#sh -c 'cat > /etc/sudoers.d/99_packer' << EOF
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#
#EOF
#chmod 0440 /etc/sudoers.d/99_packer


if [ ! "0" = "${ADD_VAGRANTUSER}" ] ; then
#DIR_MODE=0750 
useradd -g users -m -G wheel -s /bin/bash -c 'Vagrant User' vagrant ;
echo -n "vagrant:vagrant" | chpasswd ;
chown -R vagrant:\$(id -gn vagrant) /home/vagrant ;

#sh -c 'cat > /etc/sudoers.d/99_vagrant' << EOF ;
#Defaults:vagrant !requiretty
#\$(id -un vagrant) ALL=(ALL) NOPASSWD: ALL
#
#EOF
#chmod 0440 /etc/sudoers.d/99_vagrant ;
fi


sed -i "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /etc/sudoers
sed -i "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /etc/sudoers
sed -i "s|^[^#].*requiretty|# Defaults requiretty|" /etc/sudoers


sh -c 'cat >> /etc/ssh/sshd_config' << EOF
TrustedUserCAKeys /etc/ssh/sshca-id_ed25519.pub
RevokedKeys /etc/ssh/krl.krl
#HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

EOF


echo "Customize initial ramdisk (hooks: lvm)" ; sleep 3
#sed -i '/^HOOK/ s|filesystems|encrypt lvm2 filesystems|' /etc/mkinitcpio.conf	# encrypt hook only if crypted root partition
sed -i '/^HOOK/ s|filesystems|lvm2 filesystems|' /etc/mkinitcpio.conf
mkinitcpio -p linux-lts ; mkinitcpio -P


echo "Bootloader installation & config" ; sleep 3
mkdir -p /boot/efi/EFI/\${ID} /boot/efi/EFI/BOOT
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=\${ID} --recheck --removable
grub-install --target=i386-pc --recheck /dev/$DEVX
cp /boot/efi/EFI/\${ID}/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI

#sed -i -e "s|^GRUB_TIMEOUT=.*$|GRUB_TIMEOUT=1|" /etc/default/grub
sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 text xdriver=vesa nomodeset rootdelay=5"|' /etc/default/grub
#sed -i -e '/GRUB_CMDLINE_LINUX_DEFAULT/ s|="\(.*\)"|="\1 video=1024x768 "|' /etc/default/grub
echo 'GRUB_PRELOAD_MODULES="lvm"' >> /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

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
