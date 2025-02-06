{
  description = "Custom Linux kernel development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }: 
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [];
        };
        
        linuxSrc = pkgs.fetchurl {
          url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.75.tar.xz";
          sha256 = "sha256-99+x+pcWuhOdC0yBYVNYFtQA3qIdWUP1E0SEKbF5ApA=";  # nix-prefetch-url --unpack "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.75.tar.xz"
        };

        busyboxSrc = pkgs.fetchurl {
          url = "https://busybox.net/downloads/busybox-1.37.0.tar.bz2";
          sha256 = "19gs46585jr98ghqnnh6blr748zj3phc71yxfbzpsl869mqn2cdl";
        };

        buildKernel = pkgs.stdenv.mkDerivation {
          name = "custom-linux-kernel";
          src = linuxSrc;
          nativeBuildInputs = with pkgs; [
            bc bison flex gcc elfutils ncurses openssl
          ];

          buildPhase = ''
            make tinyconfig
            make 
          '';

          installPhase = ''
            mkdir -p $out/home/user/MicrOS
            cp arch/x86/boot/bzImage $out/home/user/MicrOS
          '';
        };

        buildBusybox = pkgs.stdenv.mkDerivation {
          name = "custom-busybox";
          src = busyboxSrc;
          buildInputs = with pkgs; [ ncurses ];

          buildPhase = ''
            make CONFIG_STATIC=y
          '';

          installPhase = ''
            mkdir -p $out/initramfs
            make CONFIG_PREFIX=$out/initramfs install
          '';
        };

        createInitramfs = pkgs.writeShellScriptBin "create-initramfs" ''
          # Create initramfs
          cd ${buildBusybox}/initramfs
          rm linuxrc
          chmod +x init
          
          # Create bootable image
          dd if=/dev/zero of=boot.img bs=1M count=50
          mkfs.vfat boot.img
          mkdir mnt
          mount boot.img mnt
          
          cp ${buildKernel}/boot/bzImage mnt/
          
          cd ..
          find initramfs | cpio -o -H newc > mnt/init.cpio
          umount mnt
          
          echo "Bootable image created: $(pwd)/boot.img"
        '';

      in {
        packages = {
          kernel = buildKernel;
          busybox = buildBusybox;
          initramfs-tool = createInitramfs;
        };

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            bc bison flex gcc elfutils ncurses openssl
            syslinux dosfstools vim
          ];
        };

        apps = {
          run-vm = {
            type = "app";
            program = "${pkgs.writeShellScriptBin "run-vm" ''
              exec ${pkgs.qemu}/bin/qemu-system-x86_64 \\
                -kernel ${buildKernel}/boot/bzImage \\
                -initrd boot.img \\
                -nographic \\
                -enable-kvm
            ''}";
          };
        };
      }
    );
}