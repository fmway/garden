{ den, config, lib, ... }: let
  inherit (den.lib) policy; inherit (policy) pipe;
in {
  
  den.schema.clan-machine = {
    includes = [ den.default ];
    isEntity = true;
  };
  den.schema.clan-instance = {
    includes = [ den.default ];
    isEntity = true;
  };

  den.schema.host.imports = [
    ({ host, lib, ... }:
    {
      options = {
        clan.enable = lib.mkEnableOption "enable clan";
        clan.machineName = lib.mkOption {
          type = lib.types.str;
          default = host.name;
        };
      };
    })
  ];
  den.schema.host.includes = [
    den.policies.clan-to-nixos
  ];
  den.policies.clan-to-nixos =
    { host, ... }:
      (policy.provide {
        class = "nixos";
        module.imports = [
          (config.flake.clan.outputs.moduleForMachine.${host.clan.machineName} or {})
        ];
      });
}
