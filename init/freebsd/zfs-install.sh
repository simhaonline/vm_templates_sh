#!/bin/sh -x

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su -m root -c 'sh -xs - arg1 argN'" < script.sh

#sh /tmp/disk_setup.sh gpart_vmdisk zfs bsd0
#sh /tmp/disk_setup.sh format_partitions zfs bsd0
#sh /tmp/disk_setup.sh mount_filesystems

# passwd crypted hash: [md5|sha256|sha512] - [$1|$5|$6]$...
# python -c "import crypt,getpass ; print(crypt.crypt(getpass.getpass(), '\$6\$16CHARACTERSSALT'))"
# perl -e "print crypt('password', '\$6\$16CHARACTERSSALT') . \"\n\""

set -x
export DEVX=${DEVX:-da0} ; export GRP_NM=${GRP_NM:-bsd0} ; export ZPOOLNM=${ZPOOLNM:-fspool0}
export MIRROR=${MIRROR:-mirror.math.princeton.edu/pub/FreeBSD}
ADD_VAGRANTUSER=${ADD_VAGRANTUSER:-0}

export INIT_HOSTNAME=${1:-freebsd-boxv0000}
#export PLAIN_PASSWD=${2:-abcd0123}
export CRYPTED_PASSWD=${2:-\$6\$16CHARACTERSSALT\$o/XwaDmfuxBWVf1nEaH34MYX8YwFlAMo66n1.L3wvwdalv0IaV2b/ajr7xNcX/RFIPvfBNj.2Qxeh7v4JTjJ91}

echo "Create /etc/fstab" ; sleep 3
mkdir -p /mnt/etc /mnt/compat/linux/proc
cat << EOF > /mnt/etc/fstab
/dev/gpt/${GRP_NM}-fsSwap    none        swap    sw      0   0

procfs             /proc       procfs  rw      0   0
linprocfs          /compat/linux/proc  linprocfs   rw  0   0

EOF


echo "Setup EFI boot" ; sleep 3
mkdir -p /mnt/boot/efi ; mount -t msdosfs /dev/${DEVX}p2 /mnt/boot/efi
(cd /mnt/boot/efi ; mkdir -p EFI/freebsd EFI/BOOT)
cp /boot/loader.efi /boot/zfsloader /mnt/boot/efi/EFI/freebsd/
cp /boot/loader.efi /boot/zfsloader /mnt/boot/efi/EFI/BOOT/
cp /boot/loader.efi /mnt/boot/efi/EFI/BOOT/BOOTX64.EFI


# ifconfig wlan create wlandev ath0
# ifconfig wlan0 up scan
# dhclient wlan0

ifdev=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)
#wlan_adapter=$(ifconfig | grep -B3 -i wireless) # ath0 ?
#sysctl net.wlan.devices ; sleep 3


sysctl kern.geom.debugflags ; sysctl kern.geom.debugflags=16
sysctl kern.geom.label.disk_ident.enable=0
sysctl kern.geom.label.gptid.enable=0
sysctl kern.geom.label.gpt.enable=1


echo "Extracting freebsd-dist archives" ; sleep 3
#for file in kernel base lib32 ; do
#    (fetch -o - ftp://${MIRROR}/releases/amd64/11.0-RELEASE/${file}.txz | tar --unlink -xpJf - -C ${DESTDIR:-/mnt}) ;
#done
cd /usr/freebsd-dist
for file in kernel base lib32 ; do
    (cat ${file}.txz | tar --unlink -xpJf - -C ${DESTDIR:-/mnt}) ;
done


mkdir -p /mnt/boot /mnt/etc
touch /mnt/boot/loader.conf
touch /mnt/etc/sysctl.conf ; touch /mnt/etc/rc.conf
sysrc -f /mnt/boot/loader.conf zfs_load="YES"
cat << EOF >> /mnt/etc/sysctl.conf
vfs.zfs.min_auto_ashift=12

EOF
sysrc -f /mnt/etc/rc.conf zfs_enable="YES"


cat << EOFchroot | chroot /mnt /bin/sh
set -x

chmod 1777 /tmp ; chmod 1777 /var/tmp
ln -s /usr/home /home


echo "Config keymap" ; sleep 3
sysrc keymap="us"
#kbdmap


echo "Config time zone" ; sleep 3
tzsetup UTC


cat << EOF >> /boot/loader.conf
#vfs.root.mountfrom="ufs:gpt/${GRP_NM}-fsRoot"
#vfs.root.mountfrom="zfs:${ZPOOLNM}/ROOT/default"

EOF
sysrc -f /boot/loader.conf linux_load="YES"
sysrc -f /boot/loader.conf cuse4bsd_load="YES"
sysrc -f /boot/loader.conf fuse_load="YES"
#sysrc -f /boot/loader.conf if_ath_load="YES"

sysrc linux_enable="YES"
sysrc fuse_enable="YES"

cat << EOF >> /etc/sysctl.conf
kern.geom.label.disk_ident.enable="0"
kern.geom.label.gptid.enable="0"
kern.geom.label.gpt.enable="1"

EOF


echo "Config hostname ; network" ; sleep 3
sysrc hostname="${INIT_HOSTNAME}"
#sysrc wlans_ath0="${ifdev}"
#sysrc create_args_wlan0="country US regdomain FCC"
#sysrc ifconfig_${ifdev}="WPA SYNCDHCP"
sysrc ifconfig_${ifdev}="SYNCDHCP"
sysrc ifconfig_${ifdev}_ipv6="inet6 accept_rtadv"
cat << EOF >> /etc/resolv.conf
nameserver 8.8.8.8

EOF

#resolvconf -u
cat /etc/resolv.conf ; sleep 5
sed -i '' '/127.0.1.1/d' /etc/hosts
echo "127.0.1.1    ${INIT_HOSTNAME}.localdomain    ${INIT_HOSTNAME}" >> /etc/hosts


echo "Update services" ; sleep 3
sysrc ntpd_enable="YES"
sysrc ntpd_sync_on_start="YES"
sysrc sshd_enable="YES"

#service netif restart
#dhclient -l /tmp/dhclient.leases -p /tmp/dhclient.lease.${ifdev} ${ifdev}


ASSUME_ALWAYS_YES=yes pkg -o OSVERSION=9999999 update -f
#pkg install -y nano sudo lxde-meta
pkg install -y nano sudo
pkg install -y openzfs

## Differentiate names: /usr/local/sbin/({zpool,zfs} -> {zpool,zfs}-ng)
mv /usr/local/sbin/zpool /usr/local/sbin/zpool-ng
mv /usr/local/sbin/zfs /usr/local/sbin/zfs-ng

sysrc -f /boot/loader.conf openzfs_load="YES"
sysrc -f /boot/loader.conf zfs_load="NO"
sysrc openzfs_enable="YES"
LINENO_START_MAIN=\$(grep -n 'zfs_start_main()' /etc/rc.d/zfs | cut -f1 -d:)
sed -i '' '$(( $LINENO_START_MAIN + 1))a \
        local cachefile
        for cachefile in /boot/zfs/zpool.cache /etc/zfs/zpool.cache ; do
          if [ -f $cachefile ] ; then
            zpool import -c $cachefile -a ;
          fi ;
        done
' /etc/rc.d/zfs
cat /etc/rc.d/zfs ; sleep 5


echo "Set root passwd ; add user" ; sleep 3
#echo -n "${PLAIN_PASSWD}" | pw usermod root -h 0
echo -n '${CRYPTED_PASSWD}' | pw usermod root -H 0
pw groupadd usb ; pw groupmod usb -m root

mkdir -p /home/packer
#echo -n "${PLAIN_PASSWD}" | pw useradd packer -h 0 -m -G wheel,operator -s /bin/tcsh -d /home/packer -c "Packer User"
echo -n '${CRYPTED_PASSWD}' | pw useradd packer -H 0 -m -G wheel,operator -s /bin/tcsh -d /home/packer -c "Packer User"
chown -R packer:\$(id -gn packer) /home/packer

#cat << EOF >> /usr/local/etc/sudoers.d/99_packer
#Defaults:packer !requiretty
#\$(id -un packer) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /usr/local/etc/sudoers.d/99_packer


if [ ! "0" = "${ADD_VAGRANTUSER}" ] ; then
mkdir -p /home/vagrant ;
echo -n vagrant | pw useradd vagrant -h 0 -m -G wheel,operator -s /bin/tcsh -d /home/vagrant -c "Vagrant User" ;
#echo 'set prompt = "%N@%m:%~ %# "' >> /home/vagrant/.cshrc ;
chown -R vagrant:\$(id -gn vagrant) /home/vagrant ;

#cat << EOF >> /usr/local/etc/sudoers.d/99_vagrant ;
#Defaults:vagrant !requiretty
#\$(id -un vagrant) ALL=(ALL) NOPASSWD: ALL
#EOF
#chmod 0440 /usr/local/etc/sudoers.d/99_vagrant ;
fi


cd /etc/mail ; make aliases


echo "Temporarily permit root login via ssh password" ; sleep 3
sed -i '' "/PermitRootLogin/ s|^\(.*\)$|PermitRootLogin yes|" /etc/ssh/sshd_config

cat << EOF >> /etc/ssh/sshd_config
TrustedUserCAKeys /etc/ssh/sshca-id_ed25519.pub
RevokedKeys /etc/ssh/krl.krl
#HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_ecdsa_key-cert.pub
#HostCertificate /etc/ssh/ssh_host_rsa_key-cert.pub

EOF

sed -i '' "/^%wheel.*(ALL)\s*ALL/ s|%wheel|# %wheel|" /usr/local/etc/sudoers
sed -i '' "/^#.*%wheel.*NOPASSWD.*/ s|^#.*%wheel|%wheel|" /usr/local/etc/sudoers
sed -i '' "s|^[^#].*requiretty|# Defaults requiretty|" /usr/local/etc/sudoers


echo "Config pkg repo nearby mirror(s)" ; sleep 3
mkdir -p /usr/local/etc/pkg/repos
cat << EOF >> /usr/local/etc/pkg/repos/FreeBSD.conf
FreeBSD: { enabled: false }

FreeBSD-nearby: {
	url: "pkg+http://${MIRRORPKG:-pkg0.nyi.freebsd.org}/\${ABI}/quarterly",
	mirror_type: "srv",
	signature_type: "fingerprints",
	fingerprints: "/usr/share/keys/pkg",
	enabled: true
}

EOF

ASSUME_ALWAYS_YES=yes pkg -o OSVERSION=9999999 update -f

exit

EOFchroot
# end chroot commands

(cd /mnt/boot/efi ; efibootmgr -c -l EFI/freebsd/loader.efi -L FreeBSD)
(cd /mnt/boot/efi ; efibootmgr -c -l EFI/BOOT/BOOTX64.EFI -L Default)
efibootmgr -v ; sleep 3
read -p "Activate EFI BootOrder XXXX (or blank line to skip): " bootorder
if [ ! -z "$bootorder" ] ; then
  efibootmgr -a $bootorder ;
fi


cp -vR /tmp/init.tar /mnt/root/ ; sleep 5

read -p "Enter 'y' if ready to unmount & reboot [yN]: " response
if [ "y" = "$response" ] || [ "Y" = "$response" ] ; then
  umount /mnt/boot/efi ; rm -r /mnt/boot/efi ;
  sync ; swapoff -a ; umount -a ; zfs umount -a ; zpool export $ZPOOLNM
  reboot ; #poweroff ;
fi
