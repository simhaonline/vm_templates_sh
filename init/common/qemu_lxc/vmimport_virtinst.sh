#!/bin/sh -x

# example usage ([defaults]):
#   sh vmimport_virtinst.sh [freebsd-Release-zfs]

STORAGE_DIR=${STORAGE_DIR:-`dirname $0`}

#-------------- using virtinst ------------------
CONNECT_OPT=${CONNECT_OPT:---connect qemu:///system}

GUEST=${1:-freebsd-Release-zfs}
VBIOS_OPTS=${VBIOS_OPTS:---boot uefi,loader=${STORAGE_DIR}/OVMF/OVMF_CODE.fd}

virt-install ${CONNECT_OPT} --memory 2048 --vcpus 2 \
  --controller usb,model=ehci --controller virtio-serial \
  --console pty,target_type=virtio --graphics vnc,port=-1 \
  --network network=default,model=virtio-net,mac=RANDOM \
  --boot menu=on,cdrom,hd,network --controller scsi,model=virtio-scsi \
  --disk bus=scsi,path=${STORAGE_DIR}/${GUEST}.qcow2,cache=writeback,discard=unmap,format=qcow2 \
  ${VBIOS_OPTS} -n ${GUEST} --import

sleep 30 ; virsh ${CONNECT_OPT} vncdisplay ${GUEST}
#sleep 5 ; virsh ${CONNECT_OPT} dumpxml ${GUEST} > ${STORAGE_DIR}/${GUEST}.xml
#------------------------------------------------
