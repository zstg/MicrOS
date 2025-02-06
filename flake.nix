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

        buildKernel = pkgs.stdenv.mkDerivation {
          name = "custom-linux-kernel";
          src = linuxSrc;
          nativeBuildInputs = with pkgs; [ bc bison flex gcc ncurses openssl ];

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
          nativeBuildInputs = with pkgs; [ elfutils cpio util-linux dosfstools syslinux ];
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

                cd $out/MicrOS/initramfs
                find . | cpio -o -H newc > ../init.cpio   
                cd ..

                dd if=/dev/zero of=boot.img bs=1M count=50
                mkfs -t fat boot.img
                syslinux boot.img

                mount boot.img m/
                cp bzImage init.cpio m/
                umount m/

                # run `qemu-system-x86_64 boot.img
                # enter /bzImage -initrd=/init.cpio in the `boot:` prompt

          '';
        };

        run-qemu = pkgs.writeShellScriptBin "run-qemu" ''
      exec ${pkgs.qemu_kvm}/bin/qemu-system-x86_64 \
        -enable-kvm \
        -m 2048 \
        -cpu host \
        -drive file=${buildBusybox}/MicrOS/boot.img,format=raw \
        -serial stdio \
        -monitor stdio \
        -vnc :0 \
        "$@"
    '';

      in {
        packages = {
          kernel = buildKernel;
          busybox = buildBusybox;
          qemu = run-qemu;
        };

        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            bc bison flex gcc elfutils ncurses openssl
            syslinux dosfstools vim cpio
          ];
          shellHook = ''
          echo "Custom kernel development environment initialized."
          echo "Run 'qemu-runner' to start the VM."
      '';
        };
      }
    );
}