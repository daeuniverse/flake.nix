{
  description = "Nix flake for dae and daed ";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pnpm2nix = {
      url = "github:Ninlives/pnpm2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, flake-parts, pre-commit-hooks, nixpkgs, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
      ];
      systems = [ "x86_64-linux" "aarch64-linux" ];
      perSystem = { config, self', inputs', pkgs, system, ... }: {
        packages =
          let
            version = pkgs.lib.substring 0 8 self.lastModifiedDate
              or self.lastModified or "19700101";
          in
          {
            dae = pkgs.callPackage (import ./dae/package.nix version) { };
          };

        checks = {
          pre-commit-check = inputs.pre-commit-hooks.lib.${system}.run {
            src = inputs.nixpkgs.lib.cleanSource ./.;
            hooks = { nixpkgs-fmt.enable = true; };
          };
        };
      };
      flake = {
        nixosModules = { dae = import ./dae/module.nix inputs; };
        overlays = rec {
          default = dae;
          dae = final: prev: { dae = inputs.self.packages.dae; };
        };
      };
    };
}
