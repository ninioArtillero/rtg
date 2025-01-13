{ compiler ? "default" }:

let
  # Pinning nixpkgs with nixpkgs tools
  bootstrap = import <nixpkgs> { };

  # Nix packages git revision information in JSON generated by
  # REV = nix-instantiate --eval --expr 'builtins.readFile <nixpkgs/.git-revision>'
  # to get the commit hash and
  # nix-prefetch-git https://github.com/NixOS/nixpkgs.git $REV > nixpkgs.json
  nixpkgs = builtins.fromJSON (builtins.readFile ./nixpkgs.json);

  src = bootstrap.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    inherit (nixpkgs) rev sha256;
  };

  pkgs = import src { };

  haskellPackages = if compiler == "default" then
    #pkgs.haskellPackages # Use the default ghc version shipped with nixpkgs
    pkgs.haskell.packages.ghc948 # Use this project's development ghc version
  else
    pkgs.haskell.packages.${compiler};

  # Package overrides.
  # Using forks for Euterpea and HSoM.
  # Nix derivations from source repositories are generated by
  # cabal2nix <PACKAGE-REPOSIROTY-URL> > <PACKAGE>.nix
  # while specific versions overrides from cabal are generated by
  # cabal2nix cabal://<PACKAGE-NAME>-<VERSION-NUMBER> > <PACKAGE>.nix
  config = {
    packageOverrides = pkgs: rec {
      haskellPackages = pkgs.haskellPackages.override {
        overrides = haskellPackagesNew: haskellPackagesOld: rec {
          Euterpea =
            haskellPackagesNew.callPackage ./nix/Euterpea.nix { };

          HSoM =
            haskellPackagesNew.callPackage ./nix/HSoM.nix { };
        };
      };
    };
  };

in { project = haskellPackages.callPackage ./project.nix { }; }
