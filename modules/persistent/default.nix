{ den, lib, inputs, ... }: let
  inherit (den.lib) policy;
  inherit (policy) pipe;
  inherit (import ../../utils.nix { inherit lib; }) deepMergeList;

  persysOpt = { config, ... }:
  {
    options.persistent = {
      enable = lib.mkEnableOption "Enable impermanence/preservation support for this host";
      diskType = lib.mkOption {
        type = lib.types.enum [
          # "btrfs" # TODO
          "zfs"
        ];
        default = "zfs";
      };
      # FIXME: can we do automatically instead?
      rollbackCommands = lib.mkOption {
        type = lib.types.lines;
        example = lib.literalExpression ''
          '''
            zfs rollback -r zroot/ROOT@blank
          '''
        '';
      };
      implementation = lib.mkOption {
        type = lib.types.enum [ "impermanence" "preservation" ];
        default = "impermanence";
      };
      defaultDirectory = lib.mkOption {
        description = "Primary persistence directory path";
        type = lib.types.str;
        default = "/persist";
      };
      cacheDirectory = lib.mkOption {
        description = "Cache persistence directory path";
        type = lib.types.str;
        default = config.persistent.defaultDirectory;
      };
    };
  };

  _impermanenceOpts = { mode = null; method = null; directory = null; file = null; hideMount = null; allowTrash = null; persistentStoragePath = null; user = null; group = null; };
  _preservationOpts = { mode = null; how = null; directory = null; file = null; inInitrd = null; user = null; group = null; configureParent = null; parent = null; mountOptions = null; createLinkTarget = null; };
  f = impl: v:
    if impl == "impermanence" then
      map (x: if builtins.isString x then x else builtins.intersectAttrs _impermanenceOpts x) v
    else
      map (x: if builtins.isString x then x else builtins.intersectAttrs _preservationOpts x) v;

  normalize = impl: builtins.mapAttrs (k: v: {
    directories = f impl (v.directories or []);
    files = f impl (v.files or []);
  } // lib.optionalAttrs (v ? users) {
    users = normalize impl v.users;
  });

  fix = implementation: v:
    if implementation == "impermanence" then {
      environment.persistence = builtins.mapAttrs (_: v: v // { hideMounts = true; }) v;
    } else {
      preservation = {
        enable = true;
        preserveAt = v;
      };

      systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

      # FIXME: still not understand wtf this is for
      # let the service commit the transient ID to the persistent volume
      # systemd.services.systemd-machine-id-commit = {
      #   unitConfig.ConditionPathIsMountPoint = [
      #     ""
      #     "/persist/etc/machine-id"
      #   ];
      #   serviceConfig.ExecStart = [
      #     ""
      #     "systemd-machine-id-setup --commit --root /persist"
      #   ];
      # };
    };
in {
  den.quirks.persistence.description = "Persistence quirks";

  den.schema.host.imports = [ persysOpt ];
  den.schema.host.includes = [
    den.policies.persistence-to-host
    den.policies.persistence-to-nixos
  ];

  den.schema.user.includes = [
    den.policies.expose-persistence
    den.policies.persistence-to-host
  ];

  den.policies.persistence-to-nixos = { host, ... }: let
    x = host.persistent.implementation;
  in lib.optional (host.persistent.enable)
    (policy.include {
      nixos = { persistence, ... }:
      {
        imports = [
          inputs.${x}.nixosModules.${x}
        ];
        config = fix x (deepMergeList (map (normalize x) (lib.unique persistence)));
      };
    });

  den.policies.expose-persistence =
    { host, ... }:
      pipe.from "persistence" [ pipe.expose ];

  den.policies.persistence-to-host =
    { host, ... }:
      (policy.resolve.shared { persistent = host.persistent; });
}
