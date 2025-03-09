# MicrOS
Run this inside a Docker container: `docker run --name baby_penguin --privileged -it ubuntu`
```bash
apt update
apt install -y xz-utils wget bzip2 git vim make gcc libncurses-dev flex bison bc cpio libelf-dev libssl-dev syslinux dosfstools
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.17.tar.xz
tar xf linux-6.12.17.tar.xz
rm linux-6.12.17.tar.xz
cd linux-6.12.17/
cp ../kernel.config .config
make
# make tinyconfig # enable 64-bit kernel (important), TTY and printk, ELF and #!, initramfs/initrd support.
mkdir ../out
# docker cp baby_penguin:/linux-6.12.17/arch/x86/boot/bzImage output/
cp arch/x86/boot/bzImage ../out
cd .. && rm -rf linux-6.12.17/ 

```
```bash
wget https://busybox.net/downloads/busybox-1.37.0.tar.bz2
tar xf busybox-1.37.0.tar.bz2
rm busybox-1.37.0.tar.bz2
cd busybox-1.37.0/
cp ../busybox.config .config
make
# docker cp baby_penguin:/busybox-1.37.0/busybox output/
cp ./busybox ../out/
cd .. && rm -rf busybox-1.37.0/
```
- [X] BUILD STATIC binary (no shared libs)
- turn off all networking utilities
no other changes

<!-- add `exec /busybox sh` to init>
<!--
Add /bin/sh and shebang to init

```bash
rm linuxrc
chmod +x init
find . | cpio -o -H newc > ../init.cpio
cd ..
```
-->
```bash
# Run this on the host
cd out/
find . | cpio -o -H newc > init.cpio
```

```bash
dd if=/dev/zero of=boot bs=1M count=50
mkfs -t fat boot
```
```bash
# rm -rf m
syslinux boot
mkdir m
mount boot m
cp bzImage init.cpio m
umount m
```

On host
```bash
mkdir test && cd test
docker cp bcd2c389830f:/boot-files/boot .
qemu-system-x86_64 boot /bzImage -initrd=/init.cpio
```
