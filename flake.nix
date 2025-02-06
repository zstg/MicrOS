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
          sha256 = "sha256-MxHf8y50ZJn03w1d8E1+s5Y4LX4Qi7klDntRm4NwQ6Q=";
        };

        buildKernel = pkgs.stdenv.mkDerivation {
          name = "custom-linux-kernel";
          src = linuxSrc;
          nativeBuildInputs = with pkgs; [ bc bison flex gcc elfutils ncurses openssl sudo ];

          buildPhase = ''
            cp ${./kernel.config} .config
            make -j $(nproc)
          '';

          installPhase = ''
            mkdir -p $out/MicrOS
            cp arch/x86/boot/bzImage $out/MicrOS
          '';
        };

        buildBusybox = pkgs.stdenv.mkDerivation {
          name = "custom-busybox";
          unpackPhase = ":";
          dontUnpack = true;
          dontConfigure = true;
          dontBuild = true;
          installPhase = ''
                mkdir -p $out/MicrOS/initramfs/bin/
                cp -r ${pkgs.pkgsStatic.busybox}/* $out/MicrOS/initramfs/
                rm -rf $out/MicrOS/initramfs/{default.script,linuxrc}
                
                #echo -e "#!/bin/sh\n\n/bin/sh" > $out/MicrOS/initramfs/init
                #chmod +x $out/MicrOS/initramfs/init
                ln -sf $out/MicrOS/initramfs/bin/sh $out/MicrOS/initramfs/init
            '';
        };

        createInitramfs = pkgs.writeShellScriptBin "create-initramfs" ''     
          cd $out/MicrOS/initramfs
          find . | cpio -o -H newc > ../init.cpio   
          cd ..
          dd if=/dev/zero of=boot bs=1M count=50
          mkfs -t fat boot

          rm -rf m
          syslinux boot
          mkdir m
          mount boot m
          cp bzImage init.cpio m
          umount m
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