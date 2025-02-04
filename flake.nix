{
  description = "A minimal Linux kernel and BusyBox system.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    linuxSrc = pkgs.fetchurl {
      url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.12.10.tar.xz";
      sha256 = "sha256-SlFuXtdIU3pzy0LsR/u+tt+LEpjoiSwpwOkd55CVspc=";
    };

    busyboxSrc = pkgs.fetchurl {
      url = "https://busybox.net/downloads/busybox-1.36.1.tar.bz2";
      sha256 = "sha256-uMwkyVdNgJ5yecO+NJeVxdXOtv3xnKcJ+AzeUOR94xQ=";
    };

    kernel = pkgs.stdenv.mkDerivation {
      name = "linux-6.13";
      src = linuxSrc;
      buildInputs = with pkgs; [ bc autoconf flex bison ];
      configurePhase = "cp ${./kernel.config} .config";
      buildPhase = "make isoimage FDARGS=\"initrd=/init.cpio\" FDINITRD=../output/init.cpio";
      installPhase = "mkdir -p $out";
    };

    busybox = pkgs.stdenv.mkDerivation {
      name = "busybox-1.36.1";
      src = busyboxSrc;
      nativeBuildInputs = with pkgs; [ findutils cpio ];
      buildInputs = with pkgs; [ gcc musl gnumake ];

      configurePhase = "cp ${./busybox.config} .config";
      buildPhase = "make";
      installPhase = ''
        mkdir -p $out/output
        cp busybox $out/output/
        cd $out/output
        find . | cpio -H newc -o > init.cpio
      '';
    };

  in {
    packages.${system} = {
      default = pkgs.buildEnv {
        name = "MicrOS";
        paths = [
          busybox
          kernel
        ];
      };

      busybox = busybox;
      linux = kernel;

    };
  };
}
