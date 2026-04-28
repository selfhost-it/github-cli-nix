{
  description = "Nix package for GitHub CLI (gh) - GitHub on the command line";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      overlay = final: prev: {
        gh = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.gh;
          gh = pkgs.gh;
        };

        apps.default = {
          type = "app";
          program = "${pkgs.gh}/bin/gh";
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt
            nix-prefetch-url
            go
          ];
        };
      }) // {
      overlays.default = overlay;
    };
}
