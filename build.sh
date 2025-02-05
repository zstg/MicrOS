#!/usr/bin/env bash
sudo apt update 
DEBIAN_FRONTEND=noninteractive sudo apt install -y sudo rsync wget xz-utils file bzip2 git vim make gcc libncurses-dev flex bison bc cpio libelf-dev libssl-dev syslinux isolinux genisoimage g++ make libncurses-dev unzip bc bzip2 libelf-dev libssl-dev extlinux
cd src/
wget https://buildroot.org/downloads/buildroot-2024.02.10.tar.gz
tar xf buildroot-2024.02.10.tar.gz && rm -f buildroot-2024.02.10.tar.gz
cd buildroot-2024.02.10/
# copy buildroot.config to <repo>/.config
# make menuconfig
cp kernel.config src/buildroot-2024.02.10/.config
FORCE_UNSAFE_CONFIGURE=1 make -j $(nproc)

cd /workspace/MicrOS/src/buildroot-2024.02.10
mkdir -p /workspace/MicrOS/distro/temp 
cp output/images/* /workspace/MicrOS/temp/distro
cd /workspace/MicrOS/temp/distro
tar xf rootfs.tar
rm rootfs.tar
cd ..
truncate -s 100MB boot.img
mkdir mounted
mkfs boot.img
sudo mount boot.img mounted/