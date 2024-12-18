{
  self,
  ...
}:
{
  perSystem =
    {
      pkgs,
      ...
    }:
    {
      checks.vm-dae-default = pkgs.testers.runNixOSTest {
        name = "test-dae";
        nodes = {
          machine = _: {
            imports = [
              self.nixosModules.dae
            ];
            services.dae = {
              enable = true;
              config = ''
                global {
                  disable_waiting_network: true
                }
                routing {}
              '';
            };
          };
        };
        testScript = ''
          machine.wait_for_unit("dae.service")
          machine.succeed("test -e /run/netns/daens")
        '';
      };
      checks.vm-daed-default = pkgs.testers.runNixOSTest {
        name = "test-daed";
        nodes = {
          machine = _: {
            imports = [
              self.nixosModules.daed
            ];
            services.daed = {
              enable = true;
            };
          };
        };
        testScript = ''
          machine.wait_for_unit("daed.service")
        '';
      };
    };
}
