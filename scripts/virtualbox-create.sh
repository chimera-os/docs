#!/usr/bin/env bash

# Variables
HDSIZE=1000 # Host machine hard disk size
LHDSIZE=1000 # LFS hard disk size
LHDNAME="lfs"

touch vm.log # log file

# VM creation
echo "Creating a VM..."
read -p "How should it be named (lfs is taken)? " VMNAME

if [ $VMNAME == "lfs" ]
then
	echo "This name is reserved for the LFS hard disk. Changing to LFS..."
	VMNAME="LFS"
fi 

echo "Creating a VM called $VMNAME..." >> vm.log


vboxmanage createvm --name $VMNAME --ostype Ubuntu22_LTS_64 --register 
vboxmanage modifyvm $VMNAME --cpus 2 --memory 4096 --vram 12
vboxmanage showvminfo $VMNAME >> vm.log

# Hard drive creation
echo "Setting up a hard drive..."
vboxmanage createhd --filename $HOME/'VirtualBox VMs'/$VMNAME/$VMNAME.vdi --size $HDSIZE >> vm.log
vboxmanage storagectl $VMNAME --name "SATA Controller" --add sata --bootable on
vboxmanage storageattach $VMNAME --storagectl "SATA Controller" \
	--port 0 --device 0 --type hdd \
	--medium $HOME/'VirtualBox VMs'/$VMNAME/$VMNAME.vdi

# LFS' Hard disk creation
vboxmanage createhd --filename $HOME/'VirtualBox VMs'/$VMNAME/$LHDNAME.vdi --size $HDSIZE >> vm.log
vboxmanage storageattach $VMNAME --storagectl "SATA Controller" \
	--port 1 --device 0 --type hdd \
	--medium $HOME/'VirtualBox VMs'/$VMNAME/$LHDNAME.vdi