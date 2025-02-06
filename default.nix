{ nixpkgs,linuxSrc, busyboxSrc }:

let
  system = "x86_64-linux";
  pkgs = import nixpkgs{ inherit system; };
in
pkgs.stdenv.mkDerivation {
  name = "custom-linux-boot";
  src = linuxSrc;

  buildInputs = [
    pkgs.xz_utils
    pkgs.bzip2
    pkgs.make
    pkgs.gcc
    pkgs.ncurses.dev
    pkgs.flex
    pkgs.bison
    pkgs.bc
    pkgs.cpio
    pkgs.elfutils.dev
    pkgs.openssl.dev
    pkgs.syslinux
    pkgs.dosfstools
  ];

  phases = [ "unpackPhase" "buildPhase" "installPhase" ];

  buildPhase = ''
    cd linux-6.6.75
    make mrproper
    cp ${./kernel.config} .config
    make bzImage
    mkdir ../boot-files
    cp arch/x86/boot/bzImage ../boot-files/
  '';

  installPhase = ''
    cd ..
    tar xf ${busyboxSrc}
    cd busybox-1.37.0
    cp ${./busybox.config} .config
    make
    mkdir ../boot-files/initramfs
    make CONFIG_PREFIX=../boot-files/initramfs install
    
    cd ../boot-files/initramfs
    rm linuxrc
    chmod +x init
    find . | cpio -o -H newc > ../init.cpio
    cd ..
    
    dd if=/dev/zero of=boot bs=1M count=50
    mkfs.fat boot
    mkdir m
    mount boot m
    cp bzImage init.cpio m
    umount m
    
    mkdir -p $out/boot
    cp boot $out/
  '';

  dontInstall = true;
}