{ withSystem }:
{
  config,
  pkgs,
  lib,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    literalExpression
    types
    mkPackageOption
    ;

  cfg = config.services.daed;
in
{
  # disables Nixpkgs daed module to avoid conflicts
  disabledModules = [ "services/networking/daed.nix" ];

  options = {
    services.daed = {
      enable = mkEnableOption "A modern dashboard for dae";

      package = mkPackageOption (withSystem pkgs.system ({ config, ... }: config.packages)) "daed" {
        pkgsText = "flake.packages.$\{pkgs.system}.daed";
      };

      configDir = mkOption {
        type = types.str;
        default = "/etc/daed";
        description = "The daed work directory.";
      };

      listen = mkOption {
        type = types.str;
        default = "127.0.0.1:2023";
        description = "The daed listen address.";
      };

      assetsPaths = mkOption {
        type = with types; listOf str;
        default = [
          "${pkgs.v2ray-geoip}/share/v2ray/geoip.dat"
          "${pkgs.v2ray-domain-list-community}/share/v2ray/geosite.dat"
        ];
        description = ''
          Geo database required to run daed.
          Notice that this defines different from `assetsPath` in dae module.
          This will be linked into `configDir`.
        '';
        example = ''
          ["/var/lib/dae/geoip.dat" "/home/who/geosite.dat"]
        '';
      };

      openFirewall = mkOption {
        type = types.submodule {
          options = {
            enable = mkEnableOption "enable";
            port = mkOption {
              type = types.int;
              description = ''
                Port to be opened. Consist with field `tproxy_port` in config file.
              '';
            };
          };
        };
        default = {
          enable = true;
          port = 12345;
        };
        defaultText = literalExpression ''
          {
            enable = true;
            port = 12345;
          }
        '';
        description = "Open the firewall port.";
      };
    };
  };

  config =
    lib.mkIf cfg.enable

      {
        environment.systemPackages = [ cfg.package ];
        systemd.packages = [ cfg.package ];

        networking = lib.mkIf cfg.openFirewall.enable {
          firewall =
            let
              portToOpen = cfg.openFirewall.port;
            in
            {
              allowedTCPPorts = [ portToOpen ];
              allowedUDPPorts = [ portToOpen ];
            };
        };

        systemd.services.daed =
          let
            daedBin = lib.getExe cfg.package;
          in
          {
            wantedBy = [ "multi-user.target" ];
            after = [
              "network-online.target"
              "systemd-sysctl.service"
            ];
            wants = [ "network-online.target" ];

            preStart = ''
              umask 0077
              mkdir -p ${cfg.configDir}
              ${lib.foldl' (acc: elem: acc + elem + "\n") "" (
                map (n: "ln -sfn ${n} ${cfg.configDir}") cfg.assetsPaths
              )}
            '';
            serviceConfig = {
              Type = "simple";
              User = "root";
              LimitNPROC = 512;
              LimitNOFILE = 1048576;
              ExecStart = "${daedBin} run -c ${cfg.configDir} -l ${cfg.listen}";
              Restart = "on-abnormal";
            };
          };
      };
}
