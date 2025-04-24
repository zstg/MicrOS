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
      nativeBuildInputs = with pkgs; [ musl gcc ];

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

    initramfsImage = pkgs.stdenv.mkDerivation {
      name = "micros-initramfs";

      buildInputs = with pkgs; [ coreutils findutils cpio gzip ];

      phases = [ "buildPhase" ];

      buildPhase = ''
        mkdir -p $out/initramfs/{bin,sbin,dev,proc,sys}

        echo "Copying busybox..."
        cp -r ${staticBusybox}/bin/* $out/initramfs/bin/

        echo "Copying static app..."
        cp ${myStaticApp}/bin/hello $out/initramfs/bin/

        echo "Creating init script..."
        cat > $out/initramfs/init <<EOF
#!/bin/sh
mount -t proc proc /proc
exec /bin/sh
EOF
        chmod +x $out/initramfs/init

        echo "Packing initramfs..."
        cd $out/initramfs
        find . | cpio -o -H newc | gzip > $out/initramfs.cpio.gz
        cd -

        # ln -s $out/initramfs.cpio.gz $out/
      '';
    };

    runMicrOS = pkgs.writeShellApplication {
      name = "runMicrOS";

      runtimeInputs = with pkgs; [ qemu ];

      text = ''
        echo "Running MicrOS with QEMU..."
        qemu-system-x86_64 \
          -kernel ${customKernel}/bzImage \
          -initrd ${initramfsImage}/initramfs.cpio.gz \
          -m 2048
      '';
    };

  in {
    defaultPackage.x86_64-linux = runMicrOS;

    packages.x86_64-linux = {
      customKernel = customKernel;
      staticBusybox = staticBusybox;
      myStaticApp = myStaticApp;
      initramfsImage = initramfsImage;
      runMicrOS = runMicrOS;
    };

    apps.x86_64-linux.runMicrOS = {
      type = "app";
      program = "${runMicrOS}/bin/runMicrOS";
    };

    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = [ runMicrOS ];
    };
  };
}
