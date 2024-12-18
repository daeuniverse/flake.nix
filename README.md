# flake.nix

![LINT state](https://github.com/daeuniverse/flake.nix/actions/workflows/lint.yaml/badge.svg)
![EVAL state](https://github.com/daeuniverse/flake.nix/actions/workflows/eval.yaml/badge.svg)
[![built with garnix](https://img.shields.io/endpoint.svg?url=https%3A%2F%2Fgarnix.io%2Fapi%2Fbadges%2Fdaeuniverse%2Fflake.nix%3Fbranch%3Dmain)](https://garnix.io)

## Use with flake

1. Import nixosModule.

```nix
# flake.nix

{
  inputs.daeuniverse.url = "github:daeuniverse/flake.nix";
  # ...

  outputs = {nixpkgs, ...} @ inputs: {
    nixosConfigurations.HOSTNAME = nixpkgs.lib.nixosSystem {
      modules = [
        inputs.daeuniverse.nixosModules.dae
        inputs.daeuniverse.nixosModules.daed
      ];
    };
  }
}
```

2. Enable dae or daed module.

> [!NOTE]
> To see full options, check `dae{,d}/module.nix`.

```nix
# nixos configuration module
{
  # ...

  services.dae = {
      enable = true;

      openFirewall = {
        enable = true;
        port = 12345;
      };

      /* default options

      package = inputs.daeuniverse.packages.x86_64-linux.dae;
      disableTxChecksumIpGeneric = false;
      configFile = "/etc/dae/config.dae";
      assets = with pkgs; [ v2ray-geoip v2ray-domain-list-community ];

      */

      # alternative of `assets`, a dir contains geo database.
      # assetsPath = "/etc/dae";
  };
}
```

```nix
# nixos configuration module
{
  # daed - dae with a web dashboard
  services.daed = {
      enable = true;

      openFirewall = {
        enable = true;
        port = 12345;
      };

      /* default options

      package = inputs.daeuniverse.packages.x86_64-linux.daed;
      configDir = "/etc/daed";
      listen = "127.0.0.1:2023";

      */
  };
}
```

## Globally install packages


This flake contains serval different revision of packages:

+ dae (alias of dae-release)
+ dae-release (current latest release version)
+ dae-unstable (keep sync with dae `main` branch)
+ dae-experiment (specific pull request for untested features)

See details with `nix flake show github:daeuniverse/flake.nix`

```nix
# nixos configuration module
{
  environment.systemPackages =
    with inputs.daeuniverse.packages.x86_64-linux;
      [ dae daed ]; # or dae-unstable dae-experient
}
```

> [!WARNING]
> This Nix Flake provides two installation methods for the dae package:
> - NixOS Modules via the services.dae service.
> - Global System Package via environment.systemPackages.
> 
> **Important**: Do NOT enable both installation methods simultaneously, as this will result in incompatible binary version issues. Please choose one method to avoid conflicts.

## Package Options

- **Nightly Build**: Use the `dae-unstable` package for early access to new features, always synced with the latest updates. For testing specific, unpublished changes, try `dae-experiment`, pinned to feature branch commits.

- **Release Build**: Use the `dae` or `dae-release` package for stable, production-ready version. History versions are available with tags (e.g. `refs/tags/dae-v0.8.0`).

> [!WARNING]
> Note that newly introduced features can sometimes be buggy; use at your own risk. However, we still highly encourage you to check out our latest builds as it may help us further analyze features stability and resolve potential bugs accordingly.

## Script Usage

The `main.nu` script on top-level of this repo is able to help you update the package. See help message with `./main.nu`.

The cmd args looks like:
```
# usage
commands: [sync] <PROJECT> [<VERSION>] [--rev <REVISION>]
```

About **adding a new version**, if the `VERSION` you provided doesn't match any of `["release" "unstable"]`, it will:

+ Check the `--rev` arg and read its value
+ Run `nix-prefetch-git` to get its info
+ Adding a new record to `metadata.json`
+ Update the vendorHash.

The `--rev` args could pass in with any sha1 or references:

+ revision sha1 hash
+ refs/heads/<branch>
+ refs/tags/v0.0.0

Workflow for updating release and unstable:

```
./main.nu sync dae release unstable # or leave the last 2 args empty
```

workflow for updating single version:

```
./main.nu sync dae release # or unstable
```

workflow for adding a new version:

```
./main.nu sync dae sth-new --rev 'rev_hash' or refs/heads/<branch> or refs/tags/v0.0.0
# after this will produce a new package called dae-sth-new
```

## Binary cache

We use garnix cache and provide both `x86_64-linux` and `aarch64-linux` build products.

To setup the garnix cache:

```nix
nix.settings = {
  substituters = ["https://cache.garnix.io"];
  trusted-public-keys = [
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
  ];
};
```

## License

[ISC](./LICENSE) © 2023-2024 @daeuniverse
