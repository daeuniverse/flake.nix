# flake.nix

![CI state](https://github.com/daeuniverse/flake.nix/actions/workflows/lint.yaml/badge.svg)

## build with nix

```nix
$ nix build github:daeuniverse/flake.nix#packages.x86_64-linux.dae
```

## use with flake

Modify flake.nix

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


# configuration.nix

{inputs, pkgs, ...}: {


# with daed
  services.daed = {
      enable = true;
      configDir = "/etc/daed";
      listen = "0.0.0.0:2023";
      openFirewall = {
        enable = true;
        port = 12345;
      };
  };

# or with dae
  services.dae = {
      enable = true;
      disableTxChecksumIpGeneric = false;
      configFile = "/etc/dae/config.dae";
      assets = with pkgs; [ v2ray-geoip v2ray-domain-list-community ];
      # alternatively, specify assets dir
      # assetsPath = "/etc/dae";
      openFirewall = {
        enable = true;
        port = 12345;
      };
  };
};

# use packages

#...
environment.systemPackages =
  with inputs.daeuniverse.packages.x86_64-linux;
    [ dae daed ];

```

## Nightly build

If you would like to get a taste of new features and do not want to wait for new releases, you may use the `nightly` (unstable branch) flake. The `nightly` flake is always _**up-to-date**_ with the upstream `dae` and `daed` (sync with the `main` branch) projects. Most of the time, newly proposed changes will be included in PRs, will be fully tested, and will be exported as cross-platform executable binaries in builds (GitHub Action Workflow Build).

> [!WARNING]
> Noted that newly introduced features are sometimes buggy, do it at your own risk. However, we still highly encourage you to check out our latest builds as it may help us further analyze features stability and resolve potential bugs accordingly.

Adopt nightly flake

```nix
# flake.nix
{
  inputs.daeuniverse.url = "github:daeuniverse/flake.nix/unstable";
  # ...

  outputs = {nixpkgs, ...} @inputs: {
    nixosConfigurations.HOSTNAME = nixpkgs.lib.nixosSystem {
      modules = [
        inputs.daeuniverse.nixosModules.dae
        inputs.daeuniverse.nixosModules.daed
      ];
    };
  }
}
```

## License

[ISC](./LICENSE) © 2023 daeuniverse
