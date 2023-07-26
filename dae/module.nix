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

      configFilePath = lib.mkOption {
        type = lib.types.path;
        default = "/etc/dae/config.dae";
        description = mdDoc ''
          The path of dae config file, end with `.dae`.
        '';
      };

      disableTxChecksumIpGeneric = lib.mkEnableOption (lib.mkDoc "See https://github.com/daeuniverse/dae/issues/43");

      geoDatabasePath = lib.mkOption {
        type = lib.types.path;
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
    systemd.packages = [ cfg.package ];

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
