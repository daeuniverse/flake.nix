inputs: { config, lib, pkgs, ... }:

let
  cfg = config.services.dae;
  defaultDaePackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.dae;
in
{
  options = {
    services.dae = with lib;{
      enable = mkEnableOption (mkDoc "A Linux high-performance transparent proxy solution based on eBPF");

      package = mkOption {
        type = types.path;
        default = defaultDaePackage;
        defaultText = literalExpression ''
          dae.packages.${pkgs.stdenv.hostPlatform.system}.dae
        '';
        example = literalExpression "pkgs.dae";
        description = mdDoc ''
          The dae package to use.
        '';
      };

      assets = mkOption {
        description = mdDoc "assets required to run dae.";
        type = with types;(listOf path);
        default = with pkgs; [ v2ray-geoip v2ray-domain-list-community ];
      };

      openFirewall = mkOption {
        description = mdDoc ''
          need to be consist with field `tproxy_port` in config file.
        '';
        type = with types; submodule {
          options = {
            enable = mkEnableOption "enable";
            port = mkOption {
              type = types.int;
              default = 12345;
            };
          };
        };
      };

      configFilePath = mkOption {
        type = types.path;
        default = "/etc/dae/config.dae";
        description = mdDoc ''
          The path of dae config file, end with `.dae`.
        '';
      };

      disableTxChecksumIpGeneric = mkEnableOption (mkDoc "See https://github.com/daeuniverse/dae/issues/43");

      geoDatabasePath = mkOption {
        type = types.path;
        description = mdDoc ''
          The path contains geolocation database.
        '';
        default =
          let
            assetsDrv = pkgs.symlinkJoin {
              name = "dae-assets";
              paths = cfg.assets;
            };
          in
          "${assetsDrv}/share/v2ray";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    systemd.packages = [ cfg.package ];
    networking = lib.mkIf cfg.openFirewall.enable {
      firewall =
        builtins.listToAttrs
          (map (k: { name = "allowed${k}Ports"; value = [ cfg.openFirewall.port ]; }) [ "UDP" "TCP" ]);
    };

    systemd.services.dae =
      let
        daeBin = lib.getExe cfg.package;
        TxChecksumIpGenericWorkaround = with lib;(getExe pkgs.writeShellApplication {
          name = "disable-tx-checksum-ip-generic";
          text = with pkgs; ''
            iface=$(${iproute2}/bin/ip route | ${lib.getExe gawk} '/default/ {print $5}')
            ${lib.getExe ethtool} -K "$iface" tx-checksum-ip-generic off
          '';
        });
      in
      {
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStartPre = [ "" "${daeBin} validate -c ${cfg.configFilePath}" ]
            ++ (with lib; optional cfg.disableTxChecksumIpGeneric TxChecksumIpGenericWorkaround);
          ExecStart = [ "" "${daeBin} run --disable-timestamp -c ${cfg.configFilePath}" ];
          Environment = "DAE_LOCATION_ASSET=${cfg.geoDatabasePath}";
        };
      };
  };

}
