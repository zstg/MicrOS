{
  description = "MicrOS - Minimal Linux-based OS with custom kernel and busybox";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    # Kernel config file
    myConfigFile = ./kernel.config;

	kernelVersion = "6.12.7";
	
    # Kernel source
    kernelSrc = pkgs.fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${kernelVersion}.tar.xz";
      sha256 = "sha256-94X7ZIoOC2apQ7syKKS27WLJC5hc0ev2naXTjlidoM8=";
    };

    # Statically-linked busybox
    staticBusybox = pkgs.pkgsStatic.busybox;

    # Custom kernel derivation
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
        # make olddefconfig
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

    # Finalize build: create initramfs and copy outputs
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

        echo "Preparing initramfs contents..."
        # Ensure directories exist in initramfs
        mkdir -p "$OUTDIR/initramfs/bin"
        mkdir -p "$OUTDIR/initramfs/sbin"
        mkdir -p "$OUTDIR/initramfs/dev"
        mkdir -p "$OUTDIR/initramfs/proc"
        mkdir -p "$OUTDIR/initramfs/sys"

        # Copy the busybox binary
        cp result-busybox/bin/* "$OUTDIR/initramfs/bin/"

        # Create symlinks to busybox for common commands
        # cd "$OUTDIR/initramfs/bin"
        #for cmd in sh ls cp mv rm cat mkdir; do
        #    ln -s busybox $cmd
        #done

        echo -e '#!/bin/sh\nmount -t proc proc /proc\nexec /bin/sh' > "$OUTDIR/initramfs/init"
        chmod +x "$OUTDIR/initramfs/init"

        echo "Packing initramfs..."
        pushd "$OUTDIR/initramfs"
        find . | cpio -o -H newc | gzip > "$OUTDIR/initramfs.cpio.gz"
        popd

        echo "Copying kernel..."
        cp result-kernel/bzImage "$OUTDIR/"

        echo "Build complete!"
        echo "Kernel: $OUTDIR/bzImage"
        echo "Initramfs: $OUTDIR/initramfs.cpio.gz"

        echo "To test:"
        echo "  qemu-system-x86_64 -kernel $OUTDIR/bzImage -initrd $OUTDIR/initramfs.cpio.gz -m 2048"
        qemu-system-x86_64 -kernel "$OUTDIR"/bzImage -initrd "$OUTDIR"/initramfs.cpio.gz -m 2048
      '';
    };

  in {
    # Default: run the finalize script
    defaultPackage.x86_64-linux = finaliseBuild;

    # Expose components
    packages.x86_64-linux = {
      customKernel = customKernel;
      staticBusybox = staticBusybox;
      finaliseBuild = finaliseBuild;
    };

    # Make the finalize script available as an app
    apps.x86_64-linux.finaliseBuild = {
      type = "app";
      program = "${finaliseBuild}/bin/finaliseBuild";
    };

    # Add finaliseBuild to shell env
    devShells.x86_64-linux.default = pkgs.mkShell {
      packages = [ finaliseBuild ];
    };
  };
}
