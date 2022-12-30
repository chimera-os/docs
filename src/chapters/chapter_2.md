# **Setting up a devolpment environment**

This book follow the process detailed in the *Linux from Scratch* (LFS) book. To build a working distribution, we need to setup a few things. To follow this guide, I assume you use a Debian-based Linux distribution as your main operating system.

## Ubuntu VM as host machine

LFS relies on a host system to build the distribution. It is not recommended to use your personal computer for that task since errors can break your system. We will use the following setup:

- [ ] **Operating system:** Ubuntu 22.04.1 LTS (see [Ubuntu's official website](https://ubuntu.com/download/desktop) to download the `.iso` file).
- [ ] **Virtualization platform:** Oracle VM VirtualBox (see [VirtualBox' official website](https://www.virtualbox.org) to download the product).
- [ ] **VM Stats**: 15GB virtual hard drive (for the host sytem), at least 4GB of RAM, at least 2 virtual CPU, 40GB (min. 10GB[^1]) virtual hard drive (for LFS)

## VirtualBox VM setup script

[^1]: According to the LFS Book, a minimal system requires a partition of around 10GB. Since we intend to extend the distribution, we will need more disk space.
