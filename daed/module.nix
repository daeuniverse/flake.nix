{ config, lib, ... }:

let
  cfg = config.services.daed;
in
{
  # disables Nixpkgs daed module to avoid conflicts
  disabledModules = [ "services/networking/daed.nix" ];

  options = {
    services.daed = with lib;{
      enable = mkEnableOption "A modern dashboard for dae";

      package = mkOption {
        defaultText = lib.literalMD "`packages.daed` from this flake";
      };

      configDir = mkOption {
        type = types.str;
        default = "/etc/daed";
        description = "The daed work directory.";
      };

      listen = mkOption {
        type = types.str;
        default = "0.0.0.0:2023";
        description = "The daed listen address.";
      };

      openFirewall = mkOption {
        type = with types; submodule {
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

  config = lib.mkIf cfg.enable

    {
      environment.systemPackages = [ cfg.package ];
      systemd.packages = [ cfg.package ];

      networking = lib.mkIf cfg.openFirewall.enable {
        firewall =
          let portToOpen = cfg.openFirewall.port;
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
          wants = [
            "network-online.target"
          ];

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
