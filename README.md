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

## License

[ISC](./LICENSE) © 2023 daeuniverse
