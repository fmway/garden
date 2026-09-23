{ den, lib, ... }: let
  inherit (den.lib) policy;
in {
  den.policies.persistence-dir-needed-for-boot =
    { host, ... }: let
      persistDirs = [ host.persistent.defaultDirectory host.persistent.cacheDirectory ];
      isPersistDir = dir: builtins.any (lib.flip lib.hasPrefix dir) persistDirs;
    in lib.optionals host.persistent.enable [
      (policy.provide {
        class = "nixos";
        module = { lib, ... }:
        {
          options.fileSystems = lib.mkOption {
            type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
              config.neededForBoot = lib.mkDefault (isPersistDir name);
            }));
          };
        };
      })
    ];

  den.schema.host.includes = [
    den.policies.persistence-dir-needed-for-boot
  ];
}
