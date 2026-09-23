{ den, lib, ... }: let
  inherit (den.lib) policy;
in {
  den.policies.erase-disk-for-zfs =
    { host, ... }:
    lib.optionals (host.persistent.enable && host.persistent.diskType == "zfs") [
      (policy.provide {
        class = "nixos";
        module = { config, lib, ... }: let
          systemdEnabled = config.boot.loader.systemd-boot.enable;
          systemdAsStage1= config.boot.initrd.systemd.enable;
        in {
          config = lib.mkMerge [
            (lib.mkIf (!systemdAsStage1 && systemdEnabled) {
              boot.initrd.postDeviceCommands = lib.mkAfter host.persistent.rollbackCommands;
            })
            (lib.mkIf (!systemdAsStage1 && !systemdEnabled) {
              boot.initrd.postResumeCommands = lib.mkAfter host.persistent.rollbackCommands;
            })
            (lib.mkIf systemdAsStage1 {
              boot.initrd.systemd.services.rollback = {
                description = "Rollback root filesystem";
                wantedBy = [ "initrd.target" ];
                after = [ "zfs-import-zroot.service" ];
                before = [ "sysroot.mount" ];
                path = [ config.boot.zfs.package ];
                unitConfig.DefaultDependencies = "no";
                serviceConfig.Type = "oneshot";
                script = host.persistent.rollbackCommands;
              };
            })
          ];
        };
      })
    ];

  den.schema.host.includes = [
    den.policies.erase-disk-for-zfs
  ];
}
