#!/usr/bin/env bash
# docker run --rm --privileged -v ./:/data -it ubuntu bash
# bash /data/build.sh
command -v apt >/dev/null 2>&1 && apt update && DEBIAN_FRONTEND=noninteractive apt install -y sudo wget xz-utils bzip2 git vim make gcc libncurses-dev flex bison bc cpio libelf-dev libssl-dev syslinux isolinux genisoimage

mkdir -p /data/src && cd /data/src/

wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.10.tar.xz
tar xf linux-6.12.10.tar.xz

wget https://busybox.net/downloads/busybox-1.37.0.tar.bz2
tar xf busybox-1.37.0.tar.bz2

cp /data/kernel.config /data/src/linux-6.12.10/.config
cp /data/busybox.config /data/src/busybox-1.37.0/.config

cd /data/src/busybox-1.37.0/
make
# this "splits" the busybox install into individual scripts
make CONFIG_PREFIX=/data/out/initramfs install 
cd /data/out/initramfs
rm linuxrc
find . -type f -exec chmod +x {} \;
find . | cpio -o -H newc > init.cpio

cd /data/src/linux-6.12.10/
make -j $(nproc) isoimage FDARGS="initrd=/init.cpio" FDINITRD=/data/out/initramfs/init.cpio

docker cp  <container id>:/data/src/linux-6.12.10/arch/x86/boot/image.iso out/initramfs/