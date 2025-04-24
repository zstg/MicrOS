{
  description = "MicrOS - Minimal Linux-based OS with custom kernel and busybox";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    myConfigFile = ./kernel.config;
    srccode = ./hello.c;
    kernelVersion = "6.12.7";

    kernelSrc = pkgs.fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${kernelVersion}.tar.xz";
      sha256 = "sha256-94X7ZIoOC2apQ7syKKS27WLJC5hc0ev2naXTjlidoM8=";
    };

    staticBusybox = pkgs.pkgsStatic.busybox;

    customKernel = pkgs.stdenv.mkDerivation {
      name = "linux-${kernelVersion}-micros";
      src = pkgs.runCommand "unpack-kernel" {} ''
        mkdir -p $out
        tar -xf ${kernelSrc} -C $out --strip-components=1
      '';

      nativeBuildInputs = with pkgs; [
        ncurses gcc bc perl flex bison openssl pkg-config elfutils xz
      ];

      configurePhase = ''
        cp ${myConfigFile} .config
      '';

      buildPhase = ''
        make -j$(nproc)
      '';

      installPhase = ''
        mkdir -p $out
        cp arch/x86/boot/bzImage $out/
      '';

      enableParallelBuilding = true;
    };

myStaticApp = pkgs.pkgsStatic.stdenv.mkDerivation {
  pname = "my-static-app";
  version = "1.0";

  src = srccode;
  nativeBuildInputs = with pkgs;[ musl gcc ];

  unpackPhase = ''
    mkdir source
    cp ${srccode} source/hello.c
    cd source
  '';

  buildPhase = ''
    musl-gcc -static hello.c -o hello
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp hello $out/bin/
  '';
};


    finaliseBuild = pkgs.writeShellApplication {
      name = "finaliseBuild";

      runtimeInputs = with pkgs; [
        nix coreutils findutils cpio gzip bash
      ];

      text = ''
        OUTDIR="$PWD/result"
        rm -rf "$OUTDIR"
        mkdir -p "$OUTDIR/initramfs"

        echo "Building custom kernel..."
        nix build .#customKernel -o result-kernel

        echo "Building static busybox..."
        nix build .#staticBusybox -o result-busybox

        echo "Building static C app..."
        nix build .#myStaticApp -o result-myapp

        echo "Preparing initramfs contents..."
        mkdir -p "$OUTDIR/initramfs/bin"
        mkdir -p "$OUTDIR/initramfs/sbin"
        mkdir -p "$OUTDIR/initramfs/dev"
        mkdir -p "$OUTDIR/initramfs/proc"
        mkdir -p "$OUTDIR/initramfs/sys"

        cp result-busybox/bin/* "$OUTDIR/initramfs/bin/"
        cp result-myapp/bin/hello "$OUTDIR/initramfs/bin/"

        echo -e '#!/bin/sh\nmount -t proc proc /proc\nexec /bin/sh' > "$OUTDIR/initramfs/init"
        chmod +x "$OUTDIR/initramfs/init"

        echo "Packing initramfs..."
        cd "$OUTDIR/initramfs"
        find "$OUTDIR"/initramfs/bin -type f -exec chmod +x {} \;
        find . | cpio -o -H newc | gzip > "$OUTDIR/initramfs.cpio.gz"
        cd -

        echo "Copying kernel..."
        cp result-kernel/bzImage "$OUTDIR/"

        echo "Build complete!"
        echo "Kernel: $OUTDIR/bzImage"
        echo "Initramfs: $OUTDIR/initramfs.cpio.gz"

        echo "Testing: qemu-system-x86_64 -kernel $OUTDIR/bzImage -initrd $OUTDIR/initramfs.cpio.gz -m 2048"
        qemu-system-x86_64 -kernel "$OUTDIR"/bzImage -initrd "$OUTDIR"/initramfs.cpio.gz -m 2048
      '';
    };

  in {
    defaultPackage.x86_64-linux = finaliseBuild;

    packages.x86_64-linux = {
      customKernel = customKernel;
      staticBusybox = staticBusybox;
      myStaticApp = myStaticApp;
      finaliseBuild = finaliseBuild;
    };

    apps.x86_64-linux.finaliseBuild = {
      type = "app";
      program = "${finaliseBuild}/bin/finaliseBuild";
    };

    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = [ finaliseBuild ];
    };
  };
}

