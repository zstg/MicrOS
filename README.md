# MicrOS
Run this inside a Docker container: `docker run --name baby_penguin --privileged -it ubuntu`
```bash
apt update
apt install -y xz-utils wget bzip2 git vim make gcc libncurses-dev flex bison bc cpio libelf-dev libssl-dev syslinux dosfstools
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.17.tar.xz
tar xf linux-6.12.17.tar.xz
rm linux-6.12.17.tar.xz
cd linux-6.12.17/
make tinyconfig # enable 64-bit kernel (important), TTY and printk, ELF and #!, initramfs/initrd support.
mkdir ../output
docker cp baby_penguin:/linux-6.12.17/arch/x86/boot/bzImage output/
#cp arch/x86/boot/bzImage ../output
#cd ..

```
```bash
wget https://busybox.net/downloads/busybox-1.37.0.tar.bz2
tar xf busybox-1.37.0.tar.bz2
rm busybox-1.37.0.tar.bz2
cd busybox-1.37.0/
# copy config
make
docker cp baby_penguin:/busybox-1.37.0/busybox output/
```
- [X] BUILD STATIC binary (no shared libs)
- turn off all networking utilities
no other changes

```bash
# Run this on the host
cd output/
find . | cpio -o -H newc > init.cpio
```
Add /bin/sh and shebang to init

```bash
rm linuxrc
chmod +x init
find . | cpio -o -H newc > ../init.cpio
cd ..
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
