{ withSystem }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (lib)
    mkEnableOption
    mkOption
    literalExpression
    types
    optional
    getExe
    mkPackageOption
    ;

  cfg = config.services.honk;
  inherit (cfg) assets;
  genAssetsDrv =
    paths:
    pkgs.symlinkJoin {
      name = "honk-assets";
      inherit paths;
    };

  inherit (pkgs.stdenv.hostPlatform) system;
in
{

  options = {
    services.honk-proxy = {
      enable = mkEnableOption "honk, a Linux high-performance transparent proxy solution based on eBPF";

      package = mkPackageOption (withSystem system ({ config, ... }: config.packages)) "honk" {
        pkgsText = "flake.packages.\${pkgs.system}.honk";
      };

      assets = mkOption {
        type = with types; (listOf path);
        default = with pkgs; [
          v2ray-geoip
          v2ray-domain-list-community
        ];
        defaultText = literalExpression "with pkgs; [ v2ray-geoip v2ray-domain-list-community ]";
        description = "Assets required to run honk.";
      };

      assetsPath = mkOption {
        type = types.str;
        default = "${genAssetsDrv assets}/share/v2ray";
        defaultText = literalExpression ''
          "''${(symlinkJoin {
              name = "honk-assets";
              paths = assets;
          })}/share/v2ray"
        '';
        description = ''
          The path which contains geolocation database.
          This option will override `assets`.
        '';
      };

      openFirewall = mkOption {
        type = types.submodule {
          options = {
            enable = mkEnableOption "opening {option}`port` in the firewall";
            port = mkOption {
              type = types.port;
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
        description = ''
          Open the firewall port.
        '';
      };

      configFile = mkOption {
        type =
          let
            inherit (types) nullOr addCheck str;
            isAbsolutePathString = x: lib.substring 0 1 x == "/";
            isNotInStore = x: !lib.hasPrefix builtins.storeDir x;
            combineTopic = x: isAbsolutePathString x && isNotInStore x;
          in
          (nullOr (addCheck str combineTopic))
          // {
            description = "${types.str.description} (with check: should be absolute path **string** which not a store path)";
          };
        default = null;
        example = ''"/path/to/your/config.dae"'';
        description = ''
          The absolute path string of honk config file which not in nix store,
          end with `.dae`. Will fallback to `"/etc/honk/config.dae"` if this is not set.
        '';
      };

      config = mkOption {
        type = with types; (nullOr str);
        default = null;
        description = ''
          WARNING: This option will expose your config unencrypted world-readable in the nix store.
          Config text for honk.

          See <https://github.com/daeuniverse/honk/blob/main/example.dae>.
        '';
      };

      disableTxChecksumIpGeneric = mkEnableOption "" // {
        description = "See <https://github.com/daeuniverse/dae/issues/43>";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf (cfg.configFile == null) {
        environment.etc."honk/config.dae" = {
          mode = "0400";
          source = pkgs.writeText "config.dae" cfg.config;
        };
      })
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

        systemd.services.honk =
          let
            honkBin = getExe cfg.package;

            TxChecksumIpGenericWorkaround = getExe pkgs.writeShellApplication {
              name = "disable-tx-checksum-ip-generic";
              text = ''
                iface=$(${pkgs.iproute2}/bin/ip route | ${getExe pkgs.gawk} '/default/ {print $5}')
                ${getExe pkgs.ethtool} -K "$iface" tx-checksum-ip-generic off
              '';
            };

            configPath = if cfg.configFile != null then cfg.configFile else "/etc/honk/config.dae";
          in
          {
            wantedBy = [ "multi-user.target" ];
            reloadTriggers = [ cfg.config ];
            serviceConfig = {
              ExecStartPre = [
                ""
              ] ++ (optional cfg.disableTxChecksumIpGeneric TxChecksumIpGenericWorkaround);
              ExecStart = [
                ""
                "${honkBin} -c ${configPath}"
              ];
              Environment = "DAE_LOCATION_ASSET=${cfg.assetsPath}";
              TimeoutStartSec = 120;
            };
          };

        assertions = [
          {
            assertion = lib.pathExists (toString (genAssetsDrv cfg.assets) + "/share/v2ray");
            message = ''
              Packages in `assets` has no preset path `/share/v2ray` included.
              Please set `assetsPath` instead.
            '';
          }

          {
            assertion =
              let
                A = config.services.honk.config == null;
                B = config.services.honk.configFile == null;
              in
              (A && !B) || (!A && B); # xor
            message = ''
              Either `config` or `configFile` should be only set.
            '';
          }
        ];
      }
    ]
  );
}
