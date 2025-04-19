#!/usr/bin/env bash
sudo rm -rf result*

nix build .#customKernel
echo "Copying built kernel..."
sudo mv ./result ./result-kernel
sudo chmod -R 777 ./result-kernel
sudo rm -rf result-kernel/result

nix build .#staticBusybox
echo "Copying built busybox..."
sudo mv ./result ./result-busybox
sudo chmod -R 777 ./result-busybox
sudo rm -rf result-busybox/result

echo "Finalising build..."
cd result-busybox
sudo rm -rf default.script linuxrc

echo -e '#!/usr/bin/env bash\n/bin/sh' > ./init
chmod +x ./init
find . | cpio -o -H newc > ../init.cpio
cd ..

mkdir -p result/
mv result-kernel/bzImage result/
mv result-busybox/* result/

###########
# dd if=/dev/zero of=boot bs=1M count=50
# mkfs -t fat boot
# rm -rf m
# syslinux boot
# mkdir m
# mount boot m
# cp bzImage init.cpio m
# umount m
#######