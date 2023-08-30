inputs: { config, lib, pkgs, ... }:

let
  cfg = config.services.dae;
  defaultDaePackage = inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.dae;
  defaultAssets = with pkgs; [ v2ray-geoip v2ray-domain-list-community ];
  genAssetsDrv = paths: pkgs.symlinkJoin {
    name = "dae-assets";
    inherit paths;
  };
in
{
  # disables Nixpkgs dae module to avoid conflicts
  disabledModules = [ "services/networking/dae.nix" ];

  options = {
    services.dae = with lib;{
      enable = mkEnableOption
        (mkDoc "A Linux high-performance transparent proxy solution based on eBPF");

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
        description = mdDoc ''
          Assets required to run dae.
        '';
        type = with types;(listOf path);
        default = defaultAssets;
      };

      assetsPath = mkOption {
        type = types.str;
        default = "${genAssetsDrv cfg.assets}/share/v2ray";
        example = ''
          "${pkgs.symlinkJoin {
            name = "assets";
            paths = with pkgs; [ v2ray-geoip v2ray-domain-list-community ];
          }}/share/v2ray"
        '';
        description = mdDoc ''
          The path which contains geolocation database.
          This option will override `assets`.
        '';
      };

      openFirewall = mkOption {
        description = mdDoc ''
          Port to be opened. Consist with field `tproxy_port` in config file.
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

      configFile = mkOption {
        type = types.path;
        default = "/etc/dae/config.dae";
        description = mdDoc ''
          The path of dae config file, end with `.dae`.
        '';
      };

      config = mkOption {
        type = types.str;
        default = ''
          global{}
          routing{}
        '';
        description = lib.mdDoc ''
          Config text for dae.
        '';
      };


      disableTxChecksumIpGeneric = mkEnableOption (mkDoc "See https://github.com/daeuniverse/dae/issues/43");

    };
  };

  config = lib.mkIf cfg.enable

    {
      environment.systemPackages = [ cfg.package ];
      systemd.packages = [ cfg.package ];

      environment.etc."dae/config.dae" = {
        mode = "0400";
        source = pkgs.writeText "config.dae" cfg.config;
      };

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
            ExecStartPre = [ "" "${daeBin} validate -c ${cfg.configFile}" ]
              ++ (with lib; optional cfg.disableTxChecksumIpGeneric TxChecksumIpGenericWorkaround);
            ExecStart = [ "" "${daeBin} run --disable-timestamp -c ${cfg.configFile}" ];
            Environment = "DAE_LOCATION_ASSET=${cfg.assetsPath}";
          };
        };

      assertions = [
        {
          assertion = lib.pathExists (toString (genAssetsDrv cfg.assets) + "/share/v2ray");
          message = ''
            Packages in `assets` has no preset paths included.
            Please set `assetsPath` instead.
          '';
        }

        {
          assertion = !((config.services.dae.config != "global{}\nrouting{}\n")
            && (config.services.dae.configFile != "/etc/dae/config.dae"));
          message = ''
            Option `config` and `configFile` could not be set
            at the same time.
          '';
        }
      ];
    }
  ;
}
