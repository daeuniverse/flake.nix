{ config, lib, pkgs, ... }:

let
  cfg = config.services.dae;
in
{
  options = {
    services.dae = {
      enable = lib.mkEnableOption (lib.mkDoc "A Linux high-performance transparent proxy solution based on eBPF");

      package = lib.mkPackageOptionMD pkgs "dae" { };

      configFilePath = lib.mkOption {
        type = lib.types.path;
        default = "/etc/dae/config.dae";
      };

      disableTxChecksumIpGeneric = lib.mkEnableOption (lib.mkDoc "See https://github.com/daeuniverse/dae/issues/43");

      geoDatabasePath = lib.mkOption {
        type = lib.types.path;
        default =
          let
            assetsDrv = lib.symlinkJoin {
              name = "dae-assets";
              paths = with pkgs;
                [ v2ray-geoip v2ray-domain-list-community ];
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
        ExecStartPre = [ "${lib.getExe cfg.package} validate -c ${cfg.configFilePath}" ]
          ++ (with lib; optional cfg.disableTxChecksumIpGeneric (getExe pkgs.writeShellApplication {
          name = "nicComp";
          text = with pkgs; ''
            iface=$(${iproute2}/bin/ip route | ${lib.getExe gawk} '/default/ {print $5}')
            ${lib.getExe ethtool} -K "$iface" tx-checksum-ip-generic off
          '';
        }));
        Environment = "DAE_LOCATION_ASSET=${cfg.geoDatabasePath}";
      };
    };
  };

}
