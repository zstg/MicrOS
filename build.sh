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
# sudo dd if=/dev/zero of=boot bs=1M count=50
# sudo mkfs -t fat boot # needs dosfstools on Ubuntu
# sudo syslinux boot # needs syslinux on Ubuntu
# rm -rf m && mkdir m
# sudo mount boot m
# sudo cp bzImage init.cpio m
# sudo umount m
#######