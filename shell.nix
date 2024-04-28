{ nixpkgs ? import <nixpkgs> { }, compiler ? "ghc98" }:
let
  inherit (nixpkgs) pkgs;
  ghc = pkgs.haskell.packages.${compiler}.ghcWithPackages (ps: with ps; [ ]);
in pkgs.stdenv.mkDerivation {
  name = "haskell-env";
  buildInputs = [ ghc ];
  shellHook = "eval $(egrep ^export ${ghc}/bin/ghc)";
}
