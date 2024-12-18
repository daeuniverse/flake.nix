# NOTICE: All configuration in this file is just for testing
{
  pkgs,
  lib,
  ...
}:
{
  imports = [
    # reduce size. see https://sidhion.com/blog/posts/nixos_server_issues
    (
      { lib, ... }:
      {
        disabledModules = [ "security/wrappers/default.nix" ];

        options.security = {
          wrappers = lib.mkOption {
            type = lib.types.attrs;
            default = { };
          };
          wrapperDir = lib.mkOption {
            type = lib.types.path;
            default = "/run/wrappers/bin";
          };
        };
      }
    )
  ];

  # eliminate size
  services.lvm.enable = false;
  security.sudo.enable = false;
  users.allowNoPasswordLogin = true;
  documentation.man.enable = lib.mkForce false;

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.useNetworkd = true;

  networking.hostName = "tester";

  system.stateVersion = "24.05";
}
