#!/bin/sh -x

# usage:
#   sh vmrun.sh import_[qemu | lxc] [GUEST]
#   sh vmrun.sh run_virsh [GUEST]
#   or
#   sh vmrun.sh run_qemu [GUEST]
#
# example ([defaults]):
#   sh vmrun.sh run_qemu [freebsd-Release-zfs]

STORAGE_DIR=${STORAGE_DIR:-`dirname $0`}

#-------------- using virtinst ------------------
import_lxc() {
  GUEST=${1:-devuan-boxe0000}
  CONNECT_OPT=${CONNECT_OPT:---connect lxc:///}
  
  virt-install ${CONNECT_OPT} --init /sbin/init --memory 768 --vcpus 1 \
    --controller virtio-serial --console pty,target_type=virtio \
    --network network=default,model=virtio-net,mac=RANDOM \
    ${VIRTFS_OPTS:---filesystem type=mount,mode=passthrough,source=/mnt/Data0,target=9p_Data0} \
    --filesystem $HOME/.local/share/lxc/${GUEST}/rootfs,/ -n ${GUEST} &
  
  sleep 10 ; virsh ${CONNECT_OPT} ttyconsole ${GUEST}
  #sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > $HOME/.local/share/lxc/${GUEST}.xml
}

import_qemu() {
  GUEST=${1:-freebsd-Release-zfs}
  CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
  VBIOS_OPTS=${VBIOS_OPTS:---boot uefi,loader=${STORAGE_DIR}/OVMF/OVMF_CODE.fd}
  
  virt-install ${CONNECT_OPT} --memory 2048 --vcpus 2 \
    --controller usb,model=ehci --controller virtio-serial \
    --console pty,target_type=virtio --graphics vnc,port=-1 \
    --network network=default,model=virtio-net,mac=RANDOM \
    --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
    ${VIRTFS_OPTS:---filesystem type=mount,mode=passthrough,source=/mnt/Data0,target=9p_Data0} \
    --disk bus=scsi,path=${STORAGE_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,format=qcow2 \
    ${VBIOS_OPTS} -n ${GUEST} --import &
  
  sleep 30 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST}
  #sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > ${STORAGE_DIR}/${GUEST}.xml
}

run_virsh() {
  GUEST=${1:-freebsd-Release-zfs}
  CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}
  
  ## NOTE, to convert qemu-system args to libvirt domain XML:
  #  eval "echo \"$(< vmrun_qemu.args)\"" > /tmp/run_qemu.args
  #  virsh ${CONNECT_OPT} domxml-from-native qemu-argv /tmp/run_qemu.args
  
  virsh ${CONNECT_OPT} start ${GUEST}
  sleep 10 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST} ; sleep 5
  virt-viewer ${CONNECT_OPT} ${GUEST} &
}
#------------------------------------------------

#------------ using qemu-system-* ---------------
run_qemu() {
  GUEST=${1:-freebsd-Release-zfs}
  QBIOS_OPTS=${QBIOS_OPTS:-"-smbios type=0,uefi=on -bios ${STORAGE_DIR}/OVMF/OVMF_CODE.fd"}
  qemu-system-x86_64 -machine accel=kvm:hvf:tcg -smp cpus=2 -m size=2048 \
    -boot order=cd,menu=on -usb -device usb-tablet \
    -net nic,model=virtio-net-pci,macaddr=52:54:00:`openssl rand -hex 3 | sed 's|\(..\)|\1:|g; s|:$||'` \
    ${NET_OPTS:--net bridge,br=virbr0} \
    ${VIRTFS_OPTS:--virtfs local,id=fsdev0,path=/mnt/Data0,mount_tag=9p_Data0,security_model=passthrough} \
    -device virtio-scsi-pci,id=scsi0 -device scsi-hd,drive=hd0 \
    -drive file=${STORAGE_DIR}/${GUEST}.qcow2,format=qcow2,if=none,id=hd0,cache=writeback,discard=unmap \
    ${QBIOS_OPTS} -name ${GUEST} &
}
#------------------------------------------------

#------------------------------------------------
${@:-run_qemu freebsd-Release-zfs}
