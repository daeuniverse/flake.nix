{ inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      devshells.default.devshell = {
        packages = [
          inputs.nix-eval-jobs.outputs.packages.${system}.default
          pkgs.cachix
          pkgs.nix-prefetch-git
          pkgs.nushell
        ];
      };
    };
}
