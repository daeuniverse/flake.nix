{
  description = "Nix flake for dae and daed";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    inputs@{
      flake-parts,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { withSystem, ... }:
      {
        partitionedAttrs = {
          checks = "dev";
          devShells = "dev";
        };
        partitions = {
          dev.extraInputsFlake = ./dev;
          dev.module =
            { inputs, ... }:
            {
              imports = [
                inputs.pre-commit-hooks.flakeModule
                ./dev/pre-commit-hook.nix
                inputs.devshell.flakeModule
                ./dev/devshell.nix
              ];
            };
        };
        imports = [
          flake-parts.flakeModules.partitions
        ];
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        perSystem =
          {
            self',
            pkgs,
            system,
            lib,
            ...
          }:
          {
            _module.args.pkgs = import inputs.nixpkgs { inherit system; };

            packages =
              let
                metadata = (builtins.fromJSON (builtins.readFile ./metadata.json));
              in
              # dae subspecies
              (
                let
                  daeBorn =
                    {
                      version,
                      rev,
                      hash,
                      vendorHash,
                    }:
                    pkgs.callPackage ./dae/package.nix {
                      buildGoModule =
                        args:
                        pkgs.buildGoModule (
                          args
                          // {
                            inherit version;
                            src = pkgs.fetchFromGitHub {
                              owner = "daeuniverse";
                              repo = "dae";
                              inherit rev hash;
                              fetchSubmodules = true;
                            };
                            inherit vendorHash;
                            env.VERSION = version;
                          }
                        );
                    };
                  daeVers = builtins.attrNames metadata.dae;
                in
                lib.listToAttrs (lib.map (v: lib.nameValuePair "dae-${v}" (daeBorn (metadata.dae.${v}))) daeVers)
              )
              // {
                daed = pkgs.callPackage ./daed/package.nix { };
                dae = self'.packages.dae-release;
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
