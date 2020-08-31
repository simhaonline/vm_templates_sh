Vm_templates
===========================================
.. .rst to .html: rst2html5 foo.rst > foo.html
..                pandoc -s -f rst -t html5 -o foo.html foo.rst

Virtual machine templates (KVM/QEMU hybrid boot: BIOS+UEFI) using auto install methods and/or chroot install scripts.

Installation
------------
source code tarball download:
    
        # [aria2c --check-certificate=false | wget --no-check-certificate | curl -kOL]
        
        FETCHCMD='aria2c --check-certificate=false'
        
        $FETCHCMD https://bitbucket.org/thebridge0491/vm_templates_sh/[get | archive]/master.zip

version control repository clone:
        
        git clone https://bitbucket.org/thebridge0491/vm_templates_sh.git

Usage
-----
to build virtual machine using auto install methods or chroot scripts:
        
        # NOTE, relevant comments -- transfer file(s) ; run manual commands
        
        [VOL_MGR=zfs] sh vminstall_auto.sh [<distro> [<guest>]]
        
        sh vminstall_chroot.sh [<distro> [<guest>]]
        
        # build examples:
        
        [VOL_MGR=zfs] sh vminstall_auto.sh [freebsd [freebsd-Release-zfs]]
        
        sh vminstall_chroot.sh [freebsd [freebsd-Release-zfs]]

Author/Copyright
----------------
Copyright (c) 2020 by thebridge0491 <thebridge0491-codelab@yahoo.com>

License
-------
Licensed under the Apache-2.0 License. See LICENSE for details.
