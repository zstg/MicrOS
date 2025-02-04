#!/usr/bin/env bash
command -v apt >/dev/null 2>&1 && apt update && apt install -y sudo wget xz-utils bzip2 git vim make gcc libncurses-dev flex bison bc cpio libelf-dev libssl-dev syslinux isolinux genisoimage

mkdir -p /data/src && cd /data/src/

wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.10.tar.xz
tar xf linux-6.12.10.tar.xz

wget https://busybox.net/downloads/busybox-1.37.0.tar.bz2
tar xf busybox-1.37.0.tar.bz2

cd ..
cp kernel.config src/linux-6.12.10/.config
cp busybox.config src/busybox-1.37.0/.config

cd src/busybox-1.37.0/
make
make CONFIG_PREFIX=../../out/initramfs install # this "splits" the busybox install into individual scripts

cd ../../out/initramfs/
find . | cpio -o -H newc > init.cpio


cd ../../src/linux-6.12.10/
# make
make -j $(nproc) isoimage FDARGS="initrd=/init.cpio" FDINITRD=../../out/initramfs/init.cpio

# docker cp it to out/