{
  description = "flake partition. tests and dev cfg for dae";

  inputs = {
    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
    };
    nix-eval-jobs = {
      url = "github:nix-community/nix-eval-jobs";
    };
    devshell.url = "github:numtide/devshell";
  };

  outputs = _: { };
}
