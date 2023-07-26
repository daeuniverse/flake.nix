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

      tproxyPort = mkOption {
        description = mdDoc ''
          tproxy port, need to be specified if firewall running.
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
        default =
          let
            assetsDrv = with pkgs;symlinkJoin {
              name = "dae-assets";
              paths = [ v2ray-geoip v2ray-domain-list-community ];
            };
          in
          "${assetsDrv}/share/v2ray";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    systemd.packages = [ cfg.package ];
    networking = lib.mkIf cfg.tproxyPort.enable {
      firewall =
        builtins.listToAttrs
          (map (k: { name = "allowed${k}Ports"; value = [ cfg.tproxyPort.port ]; }) [ "UDP" "TCP" ]);
    };

    systemd.services.dae = {
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        ExecStartPre = [ "" "${lib.getExe cfg.package} validate -c ${cfg.configFilePath}" ]
          ++ (with lib; optional cfg.disableTxChecksumIpGeneric (getExe pkgs.writeShellApplication {
          name = "nicComp";
          text = with pkgs; ''
            iface=$(${iproute2}/bin/ip route | ${lib.getExe gawk} '/default/ {print $5}')
            ${lib.getExe ethtool} -K "$iface" tx-checksum-ip-generic off
          '';
        }));
        ExecStart = [ "" "${lib.getExe cfg.package} run --disable-timestamp -c ${cfg.configFilePath}" ];
        Environment = "DAE_LOCATION_ASSET=${cfg.geoDatabasePath}";
      };
    };
  };

}
