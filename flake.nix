{
  description = "Nix flake for dae and daed";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-eval-jobs = {
      url = "github:nix-community/nix-eval-jobs";
    };
    devshell.url = "github:numtide/devshell";
    flake-parts.url = "github:hercules-ci/flake-parts";
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

            pre-commit = {
              check.enable = true;
              settings.hooks = {
                nixfmt-rfc-style.enable = true;
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
