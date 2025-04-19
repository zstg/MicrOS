{ description = "Static BusyBox and Custom Static Kernel";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";  # Use the Nixpkgs branch you prefer

  outputs = { self, nixpkgs, ... }:
  let
    system = "x86_64-linux";
    pkgs = import nixpkgs { system = system; };
    customKernel = pkgs.linux_latest.overrideAttrs (old: rec {
      kernelPatches = [
        # Add any custom patches here if needed
      ];
      kernelConfig = ./kernel.config;
      configureFlags = [ "--enable-static" "--disable-modules" ];
    });

    # Build static busybox
    staticBusybox = pkgs.busybox.overrideAttrs (old: rec {
      enableStatic = true;
      configureFlags = [ "--disable-shared" ];  # Disable shared library support
    });

  in {
    # Build custom kernel and busybox
    packages."x86_64-linux".customKernel = customKernel;
    packages."x86_64-linux".staticBusybox = staticBusybox;

    # Default package to build
    defaultPackage = staticBusybox;
  };
}
