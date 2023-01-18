# **Setting up a devolpment environment**

This book follow the process detailed in the *Linux from Scratch* (LFS) book. To build a working distribution, we need to setup a few things. To follow this guide, I assume you use a Debian-based Linux distribution as your main operating system.

## Ubuntu VM as host machine

LFS relies on a host system to build the distribution. It is not recommended to use your personal computer for that task since errors during the build process can break your system. We will use the following setup:

- [ ] **Operating system:** Ubuntu 22.04.1 LTS (see [Ubuntu's official website](https://ubuntu.com/download/desktop) to download the `.iso` file). *Don't forget to check the integrity and authenticity of your download.*
- [ ] **Virtualization platform:** Oracle VM VirtualBox (see [VirtualBox' official website](https://www.virtualbox.org) to download the product).
- [ ] **VM Stats**: 15GB virtual hard drive (for the host system), at least 4GB of RAM, at least 2 virtual CPU, 40GB (min. 10GB[^1]) virtual hard drive (for LFS)

## VirtualBox VM setup script

To easily generate a virtual machine that follows the aforementioned guidelines, we will use a simple `bash` script.

```bash
#!usr/bin/env bash

# Variables
HDSIZE=1000 # Host machine hard disk size
LHDSIZE=1000 # LFS hard disk size

touch vm.log # log file

# VM creation
echo "Creating a VM..."
read -p "How should it be named (lfs is taken)? " VMNAME

if [[ $VMNAME -eq "lfs" ]]
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
```

[^1]: According to the LFS Book, a minimal system requires a partition of around 10GB. Since we intend to extend the distribution, we will need more disk space.
