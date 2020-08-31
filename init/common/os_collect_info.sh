#!/bin/sh

# nc -l [-p] {port} > file ## nc -w3 {host} {port} < file  # netcat xfr
# ssh user@ipaddr "sudo sh -xs - arg1 argN" < script.sh  # w/ sudo
# ssh user@ipaddr "su [-m root] -c 'sh -xs - arg1 argN'" < script.sh

#[aria2c --check-certificate=false | fetch --no-verify-peer | ftp -S dont | \
#  wget -N --no-check-certificate | curl -kOL]
#aria2c --check-certificate=false <url_prefix>/script.sh

OS_NAME=$(uname -s) ; sep='#--------------------#' ; NAME="$OS_NAME"
case $OS_NAME in
  'Darwin') 
	NAME=$(sw_vers -productName) ;;
  'FreeBSD'|'OpenBSD'|'NetBSD'|'Linux')
	#NAME=$(lsb_release -i)
	if [ -f /etc/os-release ] ; then
  	    . /etc/os-release ;
	elif [ -f /usr/lib/os-release ] ; then
  	    . /usr/lib/os-release ;
	fi ;
	#sudo tar -xf /root/init.tar ;
	sudo find /root/init -name distro_pkgs.txt -exec cp {} /tmp/ \; ;
	. /tmp/distro_pkgs.txt ;;
esac

#===========================================================================#
concat_sep() {
	if [ -f "$@" ] ; then
		printf "${sep}\n$@\n" | cat - $@ ;
	else
		printf "${sep}\n$@\n" ;
		$@ ;
	fi
}

concat_sep_head1() {
	if [ -f "$@" ] ; then
		printf "${sep}\n$@ | head -n 1\n" | cat - $@ | head -n 2 ;
	else
		printf "${sep}\n$@ | head -n 1\t" ;
		$@ | head -n 1 ;
	fi
}

lang_devel_versions() {
    echo "lang_devel_versions" ; echo "" ; echo "lang_c" ; echo ""
    for cmd in 'gcc --version' 'clang --version' 'cmake --version' \
    		'automake --version' ; do
    	concat_sep_head1 "$cmd" ;
    done
    echo $sep ; echo "(gmake --version || make --version)    $(gmake --version | head -n 1 || make --version | head -n 1)"
    echo $sep ; echo "(swig3.0 -version || swig2.0 -version || swig -version)"
    echo ""
    for cmd in 'swig3.0' 'swig2.0' 'swig' ; do
        echo "$($cmd -version | head -n 2)" ;
    done
    for cmd in 'gfortran --version' 'go version' 'gopm --version' ; do
    	concat_sep_head1 "$cmd" ;
    done
    echo "" ; echo "lang_rust" ; echo ""
    for cmd in 'rustc --version' 'cargo --version' 'swiftc -version' ; do
    	concat_sep_head1 "$cmd" ;
    done
    echo $sep ; echo "scalac -version    $(scalac -version 2>&1 | head -n 1)"
	echo "" ; echo "lang_oo_c" ; echo ""
	for cmd in 'g++ --version' 'clang++ --version' 'msc -version' ; do
    	concat_sep_head1 "$cmd" ;
    done
	#nuget ; #monodevelop
    echo $sep ; echo "javac -version    $(javac -version 2>&1 | head -n 1)"
    echo $sep ; echoo "gradle --version" ; echo "$(gradle --version | head -n 3)"
	for cmd in 'sbt version' 'ant -version' ; do
    	concat_sep_head1 "$cmd" ;
    done
	#netbeans ; #eclipse
	concat_sep_head1 'valac --version'
	echo "" ; echo "lang_lisp" ; echo ""
	concat_sep_head1 "clojure -e '(println (str \"Clojure \" (clojure-version)))'"
	#leiningen
	concat_sep_head1 'sbcl -version' #; #quicklisp
	concat_sep_head1 'gosh -V'
	echo "" ; echo "lang_ml" ; echo ""
	for cmd in 'fsharpc --help' 'ghc --version' 'stack --version' \
			'ocamlbuild -version' 'opam --version' 'oasis version' 'sml -h' ; do
    	concat_sep_head1 "$cmd" ;
    done
	echo "" ; echo "lang_scripting" ; echo ""
    echo $sep ; echo "(node --version || nodejs --version) 2>/dev/null"
    echo "$($(node --version || nodejs --version) 2>/dev/null)"
	for cmd in 'npm --version' 'php --version' 'pear -V' 'pecl -V' 'composer -V' ; do
    	concat_sep_head1 "$cmd" ;
    done
    echo $sep ; echo "(python2 --version || python --version)    $(python2 --version 2>&1 || python --version 2>&1)"
    echo $sep ; echo "(pip2 --version || pip --version)    $(pip2 --version 2>&1 || pip --version 2>&1)"
	echo $sep ; echo "(pip2 list --local | grep -e setuptools -e invoke || pip list --local | grep -e setuptools -e invoke)"
	echo "$(pip2 list --local | grep -e setuptools -e invoke || pip list --local | grep -e setuptools -e invoke)"
	echo $sep ; echo "(jython --version | head -n 2)    $(jython --version 2>&1 | head -n 2)"
	for cmd in 'ruby --version' 'rake --version' 'gem --version' ; do
    	concat_sep_head1 "$cmd" ;
    done
	echo $sep ; echo "(gem list --local | grep -e hoe)    $(gem list --local | grep -e hoe)"
	for cmd in 'jruby --version' 'lua -v' 'luarocks --version' ; do
    	concat_sep_head1 "$cmd" ;
    done
	echo $sep ; echo "(perl -v | head -n 2)    $(perl -v | head -n 2)"
	for cmd in 'cpanm --version' 'groovy --version' ; do
    	concat_sep_head1 "$cmd" ;
    done
	echo "" ; echo "========================================"
}

bsd_info() {
	msgfile='msg1.txt' ; echo "($NAME)" 'collect_info' > $msgfile
	concat_sep 'uname -a' >> $msgfile
	concat_sep 'freebsd-version' >> $msgfile
    
    cat << EOF >> $msgfile
$sep
grep sshd_enable /etc/rc.conf
$(grep sshd_enable /etc/rc.conf)
EOF
    concat_sep 'sudo grep NOPASSWD `find /etc /usr/local/etc /usr/pkg/etc -type f -name sudoers 2>/dev/null`' >> $msgfile
	
	configs=$(find -L /boot /etc -type f -maxdepth 1 -name 'rc.conf*' -o -name 'loader.conf*')
	for conf in $configs ; do
		concat_sep $conf >> $msgfile ;
	done
	cat << EOF >> $msgfile
$sep
kldstat | sed 's|^ ||' | tr -s ' ' | cut -w -f5 | column
$(kldstat | sed 's|^ ||' | tr -s ' ' | cut -w -f5 | column)
EOF
	cat << EOF >> $msgfile
$sep
modstat | tr -s ' ' | cut -d' ' -f1 | column
$(modstat | tr -s ' ' | cut -d' ' -f1 | column)
EOF
	concat_sep 'service -e' | column >> $msgfile
	concat_sep 'rcctl ls on' | column >> $msgfile
    
    concat_sep 'date' >> $msgfile
    concat_sep 'locale' >> $msgfile
    cat << EOF >> $msgfile
$sep
ifconfig | grep -Ee '^[[:alnum:]]*:.*> .*' | sed 's|^\(.*>\).*|\1|':
$(ifconfig | grep -Ee '^[[:alnum:]]*:.*> .*' | sed 's|^\(.*>\).*|\1|')
EOF
    ifdev=$(ifconfig | grep '^[a-z]' | grep -ve lo0 | cut -d: -f1 | head -n 1)
    cat << EOF >> $msgfile
$sep
ip addr(s): ifconfig $ifdev | grep -e inet | cut -d' ' -f1-2
$(ifconfig $ifdev | grep -e inet | cut -d' ' -f1-2)
$sep
hostname -s: $(hostname -s) ; domainname: $(domainname)
EOF
    for file in /etc/hostname /etc/myname /etc/hosts /etc/resolv.conf ; do
    	concat_sep $file >> $msgfile ;
    done
    concat_sep 'sysctl -n kern.hostuuid' >> $msgfile
    concat_sep 'sysctl -n hw.uuid' >> $msgfile
    pkg_repos_sources >> $msgfile
    
    concat_sep 'sudo fdisk sd0' >> $msgfile
    concat_sep 'sudo disklabel -hp m sd0' >> $msgfile
    concat_sep 'gpt show -l sd0' >> $msgfile
    concat_sep 'gpart show -l' >> $msgfile
	for g_type in label eli ; do
		concat_sep "geom $g_type status -as" >> $msgfile ;
	done
	printf "${sep}\nZFS info\n" >> $msgfile
	concat_sep 'zpool version' >> $msgfile
	concat_sep 'zpool list -v' >> $msgfile
	concat_sep 'zfs list' >> $msgfile
    
	concat_sep /etc/fstab >> $msgfile
	concat_sep 'df -hT -c' >> $msgfile
	concat_sep 'df -h' >> $msgfile
	concat_sep 'sudo du -hd 1 / 2>/dev/null' | column -xc 78 >> $msgfile
    
	concat_sep 'ls -lh /home' >> $msgfile
	concat_sep "ls -lh /home/$(id -un)" >> $msgfile
	concat_sep 'id' >> $msgfile
    
    cat << EOF >> $msgfile
TERM: $TERM ; SHELL: $SHELL ; LANG: $LANG
$sep
PATH: $PATH
EOF
    concat_sep 'lpstat -s' >> $msgfile
    concat_sep 'lpc status' >> $msgfile
    cat << EOF >> $msgfile
$sep
/home/$(id -un)/[.xsession|.xinitrc]
EOF
    if [ -e "/home/$(id -un)/.xsession" ] ; then
        concat_sep "/home/$(id -un)/.xsession" >> $msgfile ;
    elif [ -e "/home/$(id -un)/.xinitrc" ] ; then
        concat_sep "/home/$(id -un)/.xinitrc" >> $msgfile ;
    else
        echo $sep >> $msgfile ;
    fi
}

linux_info() {
	msgfile='msg1.txt' ; echo "($NAME)" 'collect_info' > $msgfile
    concat_sep 'uname -a' >> $msgfile
    concat_sep 'lsb_release -a' >> $msgfile
    concat_sep '/proc/version' >> $msgfile
	if [ -f /etc/os-release ] ; then
      concat_sep '/etc/os-release' >> $msgfile ;
	elif [ -f /usr/lib/os-release ] ; then
      concat_sep '/usr/lib/os-release' >> $msgfile ;
	fi
    
#    cat << EOF >> $msgfile
#$sep
#sudo find /boot/{efi,EFI} -iname '*.efi'
#$(sudo find /boot/{efi,EFI} -iname '*.efi')
#EOF
    cat << EOF >> $msgfile
$sep
sudo find / -ipath /boot/efi/*/*.efi
$(sudo find / -ipath /boot/efi/*/*.efi)
EOF
    concat_sep 'sudo grep NOPASSWD /etc/sudoers' >> $msgfile
    if [ ! "" = "$(sudo which systemctl)" ] ; then
      concat_sep 'sudo systemctl list-units --type=service --state=active' >> $msgfile ;
    elif [ ! "" = "$(sudo which rc.d)" ] ; then
      concat_sep 'sudo rc.d list' >> $msgfile ;
    elif [ ! "" = "$(sudo which rc-status)" ] ; then
      concat_sep 'sudo rc-status --all' >> $msgfile ;
    elif [ ! "" = "$(sudo which sv)" ] ; then
      concat_sep 'sudo sv status /var/service/*' >> $msgfile ;
    else
      concat_sep 'sudo service --status-all' >> $msgfile ;
    fi
    
    concat_sep 'sudo hwclock -r' >> $msgfile
	concat_sep 'locale' >> $msgfile
    cat << EOF >> $msgfile
$sep
sudo ip -o link show | sed 's|^\([[:digit:]]*:.*>\).*|\1|':
$(sudo ip -o link show | sed 's|^\([[:digit:]]*:.*>\).*|\1|')
EOF
    ifdev=$(ip -o link | grep 'link/ether' | grep 'LOWER_UP' | sed -n 's|\S*: \(\w*\):.*|\1|p')
    cat << EOF >> $msgfile
$sep
sudo ip addr(s): ip addr show $ifdev | sed -n '/inet/ s|.*\(inet\S*\s*\S*\).*|\1|p'
$(sudo ip addr show $ifdev | sed -n '/inet/ s|.*\(inet\S*\s*\S*\).*|\1|p')
$sep
hostname -f: $(hostname -f) ; domainname: $(domainname)
EOF
    for file in /etc/hostname /etc/hosts /etc/network/interfaces /etc/resolv.conf ; do
		concat_sep "$file" >> $msgfile ;
	done
	concat_sep 'ls -l /etc/machine-id /var/lib/dbus/machine-id' >> $msgfile
    pkg_repos_sources >> $msgfile
    hddev=$(lsblk -lnpo name,label,partlabel | sed -n '/ESP/ s|.*\(/dev/[sv][a-z]*\)[0-9]*.*|\1|p')
    if [ "$(sudo which sgdisk)" ] ; then
        cat << EOF >> $msgfile ;
$sep
sudo sgdisk -V:
$(sudo sgdisk -V | head -n 1)
EOF
        concat_sep "sudo sgdisk --print $hddev" >> $msgfile ;
    fi
    if [ "$(sudo which sfdisk)" ] ; then
        cat << EOF >> $msgfile ;
$sep
sudo sfdisk -v:
$(sudo sfdisk -v | head -n 1)
EOF
        concat_sep "sudo sfdisk --list $hddev" >> $msgfile ;
    fi
#    cat << EOF >> $msgfile
#sudo parted -v:
#$(sudo parted -v | head -n 1)
#EOF
	#concat_sep "sudo parted -s $hddev unit GiB print" >> $msgfile
	#concat_sep "sudo partx --verbose --show $hddev" >> $msgfile
    
	concat_sep 'lsblk' >> $msgfile
	cat << EOF >> $msgfile
$sep
lsblk -nlpo partlabel
$(lsblk -nlpo partlabel | column -xc 78)
$sep
lsblk -nlpo label
$(lsblk -nlpo label | column -xc 78)
EOF
    
	printf "${sep}\nZFS info\n" >> $msgfile
	concat_sep 'sudo zpool version' >> $msgfile
	concat_sep 'sudo zpool list -v' >> $msgfile
	concat_sep 'sudo zfs list' >> $msgfile
	echo "LVM info" >> $msgfile
	concat_sep 'sudo pvs' >> $msgfile
	concat_sep 'sudo vgs' >> $msgfile
	concat_sep 'sudo lvs -o vg_name,lv_name,lv_attr,lv_size' >> $msgfile
	for file in /etc/crypttab /etc/fstab ; do
		concat_sep "sudo cat $file" >> $msgfile ;
	done
	concat_sep 'df -hT --total' >> $msgfile
	cat << EOF >> $msgfile
$sep
du -hd 1 /
$(du -hd 1 / 2>/dev/null | column -xc 78)
EOF
    
	concat_sep 'ls -lh /home' >> $msgfile
	concat_sep "ls -lh /home/$(id -un)" >> $msgfile
	concat_sep 'id' >> $msgfile
    
    cat << EOF >> $msgfile
$sep
TERM: $TERM ; SHELL: $SHELL ; LANG: $LANG
$sep
PATH: $PATH
EOF
    concat_sep 'lpstat -s' >> $msgfile
    cat << EOF >> $msgfile
$sep
/home/$(id -un)/[.xsession|.xinitrc]
EOF
    if [ -e "/home/$(id -un)/.xsession" ] ; then
        concat_sep "/home/$(id -un)/.xsession" >> $msgfile ;
    elif [ -e "/home/$(id -un)/.xinitrc" ] ; then
        concat_sep "/home/$(id -un)/.xinitrc" >> $msgfile ;
    else
        echo $sep >> $msgfile ;
    fi
}

macos_info() {
	msgfile='msg1.txt' ; echo "($NAME)" 'collect_info' > $msgfile
	concat_sep 'uname -a' >> $msgfile
	concat_sep 'sw_vers' >> $msgfile
	
	concat_sep 'date' >> $msgfile
	cat << EOF >> $msgfile
$sep
ifconfig | grep -Ee '^[[:alnum:]]*:.*> metric .*' | sed 's|^\(.*>\).*|\1|':
$(ifconfig | grep -Ee '^[[:alnum:]]*:.*> metric .*' | sed 's|^\(.*>\).*|\1|')
EOF
    ifdev=$(ifconfig | grep '^[a-z]' | cut -d: -f1 | head -n 1)
    cat << EOF >> $msgfile
$sep
ip addr(s): ifconfig $ifdev | grep -e 'inet ' | cut -d' ' -f1-2
$(ifconfig $ifdev | grep -e 'inet ' | cut -d' ' -f1-2)
$sep
hostname: $(hostname) ; domainname: $(domainname)
EOF
	concat_sep /etc/hosts >> $msgfile
	
	concat_sep 'diskutil coreStorage list' >> $msgfile
	concat_sep 'diskutil list' >> $msgfile
	concat_sep 'df -h' >> $msgfile
	concat_sep 'du -hd 1 / 2>/dev/null' | column -xc 78 >> $msgfile
	
	concat_sep 'ls -lh /Users' >> $msgfile
	concat_sep "ls -lh /Users/$(id -un)" >> $msgfile
	concat_sep 'id' >> $msgfile
    
    cat << EOF >> $msgfile
$sep
TERM: $TERM ; SHELL: $SHELL ; LANG: $LANG
$sep
PATH: $PATH
EOF
    concat_sep 'lpstat -s' >> $msgfile
}

collect_all() {
	tarext=${tarext:-} ; tarcmd=${tarcmd:-tar} # ? BSDs more features: gtar
	
	case $OS_NAME in
	  'Darwin') 
	    #msgfile='msg5.txt' ; echo "($NAME)" 'lang_devel_versions' > $msgfile ;
	    #lang_devel_versions >> $msgfile ;
	    msgfile='msg4.txt' ; echo "($NAME)" 'desktop applications' > $msgfile ;
	    ls -p /Applications | column >> $msgfile ;
	    msgfile='msg2.txt' ; echo "($NAME)" 'leaf_pkgs' > $msgfile ;
	    (concat_sep 'brew leaves' | column ;
	    concat_sep 'brew cask list' | column ;
	    echo "==================") >> $msgfile ;
	    
	    macos_info ;;
	  'FreeBSD'|'OpenBSD'|'NetBSD'|'Linux') 
	    #msgfile='msg5.txt' ; echo "($NAME)" 'lang_devel_versions' > $msgfile ;
	    #lang_devel_versions >> $msgfile ;
	    msgfile='msg4.txt' ; echo "($NAME)" 'desktop applications' > $msgfile ;
	    if [ -f /usr/local/share/applications ] ; then
	      ls /usr/local/share/applications | column >> $msgfile ;
	    elif [ -f /usr/share/applications ] ; then
	      ls /usr/share/applications | column >> $msgfile ;
	    fi ;
	    msgfile='msg3.txt' ; echo "($NAME)" 'explicit_pkgs' >> $msgfile ;
	    pkgs_installed explicit >> $msgfile ;
	    msgfile='msg2.txt' ; echo "($NAME)" 'leaf_pkgs' >> $msgfile ;
	    pkgs_installed leaf >> $msgfile ;
	    
		if [ "Linux" = "$OS_NAME" ] ; then
		  linux_info ;
		else
		  bsd_info ;
		fi ;;
		*) echo 'ERROR: OS is not Linux | [Free | Open | Net]BSD | Darwin(MacOS)' ;
		  echo '...exiting...' ; exit ;;
	esac

	for archive_cmd in "tar" "zip" "7za" ; do
		if [ ! "$(which $archive_cmd)" ] ; then
			continue ;
		fi ;
		case $archive_cmd in
		  'tar') ${tarcmd} -caf info.tar${tarext} msg?.txt ;;
		  'zip') zip -r info.zip msg?.txt ;;
		  '7za') 7za a info.7z msg?.txt ;;
		  *) echo 'ERROR: archive cmd is not [g]tar | zip | 7za' ;
		    echo '...exiting...' ; exit ;;
		esac ;
	done
}

#===========================================================================#

$@
