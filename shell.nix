# This is not required; flake supersedes this
with import <nixpkgs> {};
{
     testEnv = stdenv.mkDerivation {
       name = "linux-kernel-dev-env";
       buildInputs = [
           stdenv
           git
           gnumake
           ncurses
           bc
           flex
           bison
           elfutils
           openssl
           gcc
       ];
     };
}
