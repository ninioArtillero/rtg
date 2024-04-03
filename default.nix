# Soporte de Nix para proyecto Cabal.
# Referencias:
# "Nix recipes for Haskellers": https://srid.ca/haskell-nix
# Fijar una version de nixpkgs: https://nix.dev/tutorials/first-steps/towards-reproducibility-pinning-nixpkgs
# Determinar commit-hash de asociado al canal de nixos: https://discourse.nixos.org/t/how-to-see-what-commit-is-my-channel-on/4818
# Fetch nixpkgs: https://nixos.wiki/wiki/How_to_fetch_Nixpkgs_with_an_empty_NIX_PATH
#
# Este archivo es utilizado por defecto por `nix-build` y `nix-shell`.
# Al correr `nix-shell` se carga una sesión de terminal con todas las dependencias
# declaradas en el archivo `ritmoTG.cabal`.
# Desde esta sesión se pueden utilizar los comandos `cabal` para interactuar con la biblioteca.
# Utilizo Nix de esta manera para abstraer la instalación de Haskell.
#
# Se fija un commit de nixpkgs para reproducibilidad
# mediante el número de commit corto o largo.
# Por ejemplo, se puede obtener el correspondiente a la versión de NixOS de la parte final de `sudo nixos-version`
# y el hash utilizando `nix-prefetch-url --unpack "<url>"`
# Actual:
# Canal de Nix: nixos-23.11 (stable)
# 23.11.5648.44733514b72e (Tapir)
#
let
  pkgs = import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/44733514b72e.tar.gz";
    sha256 = "1cdk2s324yanzy7sz1pshnwrgm0cyp6fm17l253rbsjb6s6a0i3a";
  }) { };
in pkgs.haskell.packages.ghc98.developPackage {
  root = ./.;
  modifier = drv:
    pkgs.haskell.lib.addBuildTools drv
    (with pkgs.haskellPackages; [ cabal-install ]);
}
