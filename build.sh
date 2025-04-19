#!/usr/bin/env bash
nix build .#customKernel
echo "Copying result..."
sudo cp  -r ./result ./result-kernel
sudo chmod -R 777 ./result-kernel

nix build .#staticBusybox
echo "Copying result..."
sudo mv ./result ./result-busybox
sudo chmod -R 777 ./result-busybox

echo "Finalising build..."
cd result-busybox
sudo rm -rf default.script linuxrc
echo -e '#!/usr/bin/env bash\n/bin/sh' > ./init
chmod +x ./init
find . | cpio -o -H newc > ../init.cpio
cd ..

mkdir -p out/
cp -r result-kernel/bzImage out/
cp -r result-busybox/* out/

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