{
  description = "Linux kernel compilation environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, utils }: 
    utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        # Define source tarballs
        linuxSrc = pkgs.fetchTarball {
          url = "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.75.tar.xz";
          sha256 = "17pad7pbkx1d32qp54xqfqadixxlnrf9r997lgnh68nzkd2yyvfn"; # "${nix-prefetch-url --unpack "https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.6.75.tar.xz"}";
        };

        busyboxSrc = pkgs.fetchTarball {
          url = "https://busybox.net/downloads/busybox-1.37.0.tar.bz2";
          sha256 = "19gs46585jr98ghqnnh6blr748zj3phc71yxfbzpsl869mqn2cdl";
        };

      in {
        packages.default = pkgs.callPackage ./default.nix {
          inherit linuxSrc busyboxSrc;
        };

        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.xz
            pkgs.wget
            pkgs.bzip2
            pkgs.git
            pkgs.vim
            pkgs.gnumake
            pkgs.gcc
            pkgs.ncurses
            pkgs.flex
            pkgs.bison
            pkgs.bc
            pkgs.cpio
            pkgs.elfutils.dev
            pkgs.openssl.dev
            pkgs.syslinux
            pkgs.dosfstools
          ];
        };
      });
}