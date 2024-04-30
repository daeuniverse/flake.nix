{
  description = "Nix flake for dae and daed";

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
    nix-eval-jobs = {
      url = "github:nix-community/nix-eval-jobs";
    };
    devshell.url = "github:numtide/devshell";
  };

  outputs =
    inputs@{
      flake-parts,
      pre-commit-hooks,
      devshell,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, ... }:
      {
        imports = [
          pre-commit-hooks.flakeModule
          devshell.flakeModule
        ];
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        perSystem =
          {
            pkgs,
            system,
            lib,
            ...
          }:
          {
            _module.args.pkgs = import inputs.nixpkgs {
              inherit system;
              overlays = with inputs; [ pnpm2nix.overlays.default ];
            };

            packages = {
              dae = pkgs.callPackage ./dae/package.nix { };
              daed = pkgs.callPackage ./daed/package.nix { };
            };
            pre-commit = {
              check.enable = true;
              settings.hooks = {
                nixfmt = {
                  enable = true;
                  entry = lib.mkForce "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
                };
              };
            };
            devshells.default.devshell = {
              packages = [
                inputs.nix-eval-jobs.outputs.packages.${system}.default
                pkgs.cachix
                pkgs.nushell
              ];
            };
            formatter = pkgs.nixfmt-rfc-style;
          };
        flake =
          let
            moduleName = [
              "dae"
              "daed"
            ];
            genFlake = n: {
              nixosModules = {
                ${n} =
                  { pkgs, ... }:
                  {
                    imports = [ ./${n}/module.nix ];
                    services.${n}.package = withSystem pkgs.stdenv.hostPlatform.system (
                      { config, ... }: config.packages.${n}
                    );
                  };
              };
              overlays = {
                ${n} = final: prev: { ${n} = inputs.self.packages.${n}; };
              };
            };
          in
          inputs.nixpkgs.lib.mkMerge (
            (map genFlake moduleName)
            ++ [
              {
                overlays.default =
                  final: prev:
                  inputs.nixpkgs.lib.genAttrs moduleName (n: {
                    ${n} = inputs.self.packages.${n};
                  });
              }
            ]
          );
      }
    );
}
