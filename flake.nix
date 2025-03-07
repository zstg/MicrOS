{
  description = "Custom Linux kernel development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, utils }: 
    let
      system = "x86-64-linux";
      pkgs = import nixpkgs { inherit system; };
      
      linuxSrc = pkgs.fetchurl {
        url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.75.tar.xz";
        sha256 = "sha256-99+x+pcWuhOdC0yBYVNYFtQA3qIdWUP1E0SEKbF5ApA=";
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

        meta.description = "Custom Linux kernel compilation";
      };

      buildBusybox = pkgs.stdenv.mkDerivation {
        name = "custom-busybox";
        nativeBuildInputs = with pkgs; [ elfutils cpio util-linux dosfstools syslinux sudo];
        phases = ["installPhase"];
        dontUnpack = true;
        dontConfigure = true;
        dontBuild = true;
        installPhase = ''
            mkdir -p $out/MicrOS/initramfs/bin/
            cp -r ${pkgs.pkgsStatic.busybox}/* $out/MicrOS/initramfs/

            # Remove unwanted files
            rm -rf $out/MicrOS/initramfs/{default.script,linuxrc}

            # Use bash as init and generate CPIO archive
            ln -sf $out/MicrOS/initramfs/bin/sh $out/MicrOS/initramfs/init
            cd $out/MicrOS/initramfs
            find . | cpio -o -H newc > ../init.cpio

            # Print contents for verification
            cd ..
            dd if=/dev/zero of=boot bs=1M count=50
            mkfs -t fat boot
            syslinux boot
            sudo mount --mkdir boot m # mounts don't work inside the chroot?!
          '';
      };

      run-qemu = pkgs.writeShellScriptBin "run-qemu" ''
          exec ${pkgs.qemu_kvm}/bin/qemu-system-x86_64 ${buildBusybox}/MicrOS/boot
        '';

    in
      {
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
      };
}
