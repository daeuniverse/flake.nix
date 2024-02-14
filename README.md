# flake.nix

![CI state](https://github.com/daeuniverse/flake.nix/actions/workflows/lint.yaml/badge.svg)

## build with nix

```nix
$ nix build github:daeuniverse/flake.nix#packages.x86_64-linux.dae
```

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

```nix
# configuration.nix

# to see full options, check dae{,d}/module.nix

# with dae
  services.dae = {
      enable = true;
      package = pkgs.dae;
      disableTxChecksumIpGeneric = false;
      configFile = "/etc/dae/config.dae";
      assets = with pkgs; [ v2ray-geoip v2ray-domain-list-community ];
      openFirewall = {
        enable = true;
        port = 12345;
      };
  };
```


```nix
# with daed
  services.daed = {
      enable = true;
      package = pkgs.daed;
      configdir = "/etc/daed";
      listen = "0.0.0.0:2023";
      openfirewall = {
        enable = true;
        port = 12345;
      };
  };

```

## Directly use packages

```nix

environment.systemPackages =
  with inputs.daeuniverse.packages.x86_64-linux;
    [ dae daed ];

```

## License

[ISC](./LICENSE) © 2023 daeuniverse
