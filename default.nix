# Questo file permette a chi non usa i Flakes (come il NUR) di accedere al pacchetto.
{ pkgs ? import <nixpkgs> { } }:

{
  # Esponiamo il pacchetto gh usando callPackage sul file esistente.
  gh = pkgs.callPackage ./package.nix { };
}
