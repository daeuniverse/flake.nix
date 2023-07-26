{
  description = "Nix flake for dae and daed ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pnpm2nix = {
      url = "github:Ninlives/pnpm2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
      ];
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        packages = rec {
          default = dae;
          dae = pkgs.callPackage ./dae/package.nix { };
        };
      };
      flake = {
        nixosModules = { dae = import ./dae/module.nix { }; };
        overlays = { dae = final: prev: { dae = inputs.self.packages.dae; }; };
      };
    };
}
