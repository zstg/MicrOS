{ 
  description = "MicrOS";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; 

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { system = system; };
    
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

    # Build static busybox
    staticBusybox = pkgs.busybox.overrideAttrs (old: rec {
      enableStatic = true;
      configureFlags = [ "--disable-shared" ];  # Disable shared library support
    });

  in {
    # Build custom kernel and busybox
    packages.x86_64-linux.customKernel = customKernel;
    packages.x86_64-linux.staticBusybox = staticBusybox;

    # Default package to build
    # defaultPackage = staticBusybox; # doesn't work
  };
}