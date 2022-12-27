#!/bin/bash
# Script to generate a VirtualBox VM according to the specifications presented in Chapter 2 using the 'VBoxManage' utility.
# see https://www.oracle.com/technical-resources/articles/it-infrastructure/admin-manage-vbox-cli.html for more information.

echo "Creating a VM to build LFS..."
read -p "How should it be named? " vm_name
echo "Creating a VM called $vm_name..."

VBoxManage creatvm --name $vm_name --ostype Ubuntu_64 --register # Creating and registering the VM
VBoxManage modifyvm $vm_name --cpus 2 --memory 4096 --vram 12 # Setting parameters
VBoxManage showvminfo $vm_name