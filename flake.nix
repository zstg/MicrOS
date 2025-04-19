{
  description = "MicrOS";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { inherit system; };

    myConfigFile = ./kernel.config;

    kernelSrc = pkgs.fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.14.2.tar.xz";
      sha256 = "sha256-xcaCo1TqMZATk1elfTSnnlw3IhrOgjqTjhARa1d6Lhs=";
    };

    customKernel = pkgs.stdenv.mkDerivation {
      name = "linux-6.14.2-micros";
      src = pkgs.runCommand "unpack-kernel" {} ''
        mkdir -p $out
        tar -xf ${kernelSrc} -C $out --strip-components=1
      '';
      nativeBuildInputs = with pkgs; [ ncurses gcc bc perl flex bison openssl pkg-config elfutils xz ];
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

    staticBusybox = pkgs.busybox.overrideAttrs (old: rec {
      enableStatic = true;
      configureFlags = [ "--disable-shared" ];
    });

    finaliseBuild = pkgs.writeShellScript "finaliseBuild" ''
        #!/usr/bin/env bash
        set -euo pipefail

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

        mkdir -p result/
        mv ../result-kernel/bzImage result/
        mv ./* result/

        echo "Build complete. bzImage and init.cpio are in ./result"
      '';

  in {
    packages.x86_64-linux.customKernel = customKernel;
    packages.x86_64-linux.staticBusybox = staticBusybox;
    apps.x86_64-linux.finaliseBuild = finaliseBuild;
  };
}
