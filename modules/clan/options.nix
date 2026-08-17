{ lib, inputs, den, config, ... }: let
  inherit (import "${inputs.den}/nix/lib/entities/_types.nix" { inherit lib den; }) resolvedCtxModule;
  defaultAspect = { name = "<clan:default>"; };
  ns = config.clan.namespace;
  getAspect = name:
    if isNull ns then
      den.aspects.${name} or defaultAspect
    else
      den.ful.${ns}.${name} or defaultAspect;
  instanceType = den.lib.schema.mkInstanceType den.schema.clan-instance {
    strict = false;
    extraModules = [
      (resolvedCtxModule "clan-instance")
      ({ config, name, ... }: {
        config._module.args.instance = config;
        config._module.args.instanceName = name;
        options = {
          module.name = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          module.input = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          aspect = lib.mkOption {
            type = lib.types.raw;
            default = getAspect name;
          };
          roles = lib.mkOption {
            default = { };
            type = lib.types.attrsOf (
              lib.types.submoduleWith {
                modules = [
                  (import "${inputs.clan-core}/modules/inventoryClass/role.nix" { } { inherit lib; clanLib = inputs.clan-core.lib // {
                    types = inputs.clan-core.lib.types // {
                      uniqueDeferredSerializableModule = lib.types.json;
                    };
                  }; })
                ];
              }
            );
          };
        };
      })
    ];
  };
  machineType = den.lib.schema.mkInstanceType den.schema.clan-machine {
    strict = false;
    extraModules = [
      (resolvedCtxModule "clan-machine")
      ({ config, name, ... }: {
        config._module.args.machine = config;
        config._module.args.machineName = name;
        options = {
          aspect = lib.mkOption {
            type = lib.types.raw;
            default = getAspect name;
          };
          tags = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            apply = lib.unique;
            default = [];
          };
          machineClass = lib.mkOption {
            type = lib.types.enum [ "nixos" "darwin" ];
            default = "nixos";
          };
          deploy.targetHost = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
          deploy.buildHost = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
          };
        };
      })
    ];
  };
in {
  options.clan = {
    directory = lib.mkOption {
      type = lib.types.path;
      default = inputs.self.outPath;
    };
    namespace = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
    meta = lib.mkOption {
      description = ''
        Global information about the clan.
      '';
      type = lib.types.submoduleWith {
        modules = [
          "${inputs.clan-core}/modules/inventoryClass/meta.nix"
        ];
      };
      default = { };
    };

    exportInterfaces = lib.mkOption {
      type = lib.types.attrsOf lib.types.deferredModule;
      default = {};
    };

    inventory.instances = lib.mkOption {
      type = lib.types.attrsOf instanceType;
    };
    inventory.machines = lib.mkOption {
      type = lib.types.attrsOf machineType;
    };
  };
}
