#!/bin/bash
#set -x



QEMU=/usr/libexec/qemu-kvm

if [ -z $TDVF ]; then
TDVF=/usr/share/edk2/ovmf/OVMF.inteltdx.fd
else
echo "This is a Secure boot:   $TDVF"
echo " "
fi
sleep 1

RED="echo -en \\E[4;31m"
RESET="echo -en \\E[0;39m"

GUEST_IMG=$CURR_DIR/$GUEST_QCOW2

#---------------------------------------------------
# 1 Prepare change the password and enable the "PermitRootLogin yes"
#---------------------------------------------------
echo " "
echo " "
echo "dnf install guestfs-tools "
echo "export LIBGUESTFS_BACKEND=direct "
echo "virt-customize -a rhel-guest-image-9.4-20240226.21.x86_64.wxl.qcow2 --root-password password:123456"
echo "echo "PermitRootLogin yes" >> /etc/ssh/sshd_config"
echo " "
echo " "
echo "Please wait for boot a qemu in this windows... ..."

export LIBGUESTFS_BACKEND=direct
virt-customize -a $GUEST_IMG --root-password password:$password


# 1. Create a mount file

mkdir -p rootfs

# 2. Connect the guest image to NBD device
sudo modprobe nbd max_part=8
sudo qemu-nbd --connect=/dev/nbd0 $GUEST_IMG
# 3. Wait for connecting sucessfully
sleep 1
# 4. Mount the guest image devices to mount points created above
if [[ "$DISTRO" == "redhat" ]] ;then
sudo mount /dev/nbd0p4 rootfs
elif [[ "$DISTRO" == "ubuntu" ]] ;then
sudo mount /dev/nbd0p1 rootfs
else
echo "Do not support Distro: $DISTRO"
exit 1
fi
# 5. Sign components and replace old ones
echo PermitRootLogin yes >> rootfs/etc/ssh/sshd_config

# 6. Umount devices and disconnect
sudo umount rootfs
sudo rm -rf rootfs
sudo qemu-nbd --disconnect /dev/nbd0



# -------------------------------------------------- 
# boot a qemu:
#---------------------------------------------------

${QEMU} \
-accel kvm \
-m 4G -smp 1 \
-name process=tdxvm,debug-threads=on \
-cpu host \
-object tdx-guest,id=tdx \
-machine q35,hpet=off,kernel_irqchip=split,memory-encryption=tdx,memory-backend=ram1 \
-object memory-backend-ram,id=ram1,size=4G,private=on \
-nographic -vga none \
-chardev stdio,id=mux,mux=on,signal=off -device virtio-serial -device virtconsole,chardev=mux \
-bios ${TDVF} \
-serial chardev:mux \
-nodefaults \
-device virtio-net-pci,netdev=nic0 -netdev user,id=nic0,hostfwd=tcp::10022-:22 \
-drive file=${GUEST_IMG},if=none,id=virtio-disk0 \
-device virtio-blk-pci,drive=virtio-disk0
