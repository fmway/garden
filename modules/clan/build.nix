{ den, config, lib, inputs, ... }: let
  inherit (den.lib) policy aspects resolveEntity;
  inherit (den.lib.aspects.fx.handlers) constantHandler;
  inherit (policy) pipe;

  deepMergeList =
    builtins.zipAttrsWith (_: v: let
      f = builtins.head v;
    in
      if builtins.length v == 1 then
        f
      else if builtins.isAttrs f then
        deepMergeList v
      else if builtins.isList f then
        builtins.concatLists v
      else
        lib.last v
    );

  flatModule = module: {
    imports = builtins.concatMap (x: x.imports or []) (module.imports or []);
  };

  instanceEntity = include: args: let r = resolveEntity "clan-instance" args; in r // { includes = r.includes ++ [ include ]; };

  normalizeInstance = name: instance: builtins.mapAttrs (name: role: {
    name = name; roleName = name; settings = role.finalSettings.config;
    machines = builtins.mapAttrs (_: machine: machine.finalSettings.config) role.machines;
  }) instance.roles // { name = name; instanceName = name; };

  constructModule = instanceName: i: let
    moduleInput = if isNull i.module.input then "clan-core" else i.module.input;
    moduleName = i.module.name;
    clanService = flatModule (aspects.resolve "clan" i.resolved);
  in
  { config, ... }: let
    serviceName = config.manifest.name;
    instance = normalizeInstance instanceName config.instances.${instanceName};
  in
  {
    _module.args = { inherit serviceName instance instanceName; };
    _class = "clan.service";
    _file = "clan:instance:${instanceName}, via ${i.aspect.meta.name or "<anon>"}";
    imports = lib.optionals (!isNull moduleName) [
      inputs.${moduleInput}.clan.modules.${moduleName} # TODO: auto-resolve by manifest.name
    ] ++ lib.optionals (isNull moduleName && clanService.imports == []) [
      inputs.clan-core.clan.modules.importer
    ] ++ clanService.imports;

    roles = builtins.mapAttrs (roleName: r: let
      interfaceModule = flatModule (aspects.resolve "interface" aspect);
      
      defAspect = if roleName == "default" then i.aspect else _: {};
      aspect' = i.aspect.${roleName} or defAspect;
      aspect = instanceEntity aspect' {
        clan-instance = i;
        inherit instanceName roleName serviceName instance;
      };
    in {
      description = lib.mkDefault (aspect.description or "");
      interface = {
        imports = interfaceModule.imports;
      };
      perInstance = { settings, mkExports, machine, ... }: let
        fAspect = instanceEntity aspect { inherit settings machine mkExports; machineName = machine.name; };
        darwinModule = flatModule (aspects.resolve "darwin" fAspect);
        nixosModule = flatModule (aspects.resolve "nixos" fAspect);
      in {
        inherit nixosModule darwinModule;
      };
    }) i.roles;
  };

  r = deepMergeList (map (instanceName: let
    i = config.clan.inventory.instances.${instanceName};
  in {
    instances.${instanceName} = {
      module.name = instanceName;
      module.input = "self";
      roles = i.roles;
    };
    modules.${instanceName} = constructModule instanceName i;
  }) (builtins.attrNames config.clan.inventory.instances));

  fleet = {
    self = inputs.self;
    directory = config.clan.directory;
    meta = config.clan.meta;
    modules = r.modules or {};
    exportInterfaces = config.clan.exportInterfaces;
    inventory = {
      instances = r.instances or {};
      machines = builtins.mapAttrs (_: v: { inherit (v) deploy machineClass tags; }) config.clan.inventory.machines;
    };
    machines = builtins.mapAttrs (_: v: aspects.resolve "nixos" v.resolved) config.clan.inventory.machines;
  };
  b = inputs.clan-core.lib.clan fleet;
in {
  den.schema.flake.includes = [
    {
      flake.flake = rec {
        clan = b.config;
        clanInternals = clan.clanInternals;
        _clan = b;
        _fleet = fleet;
      };
    }
  ];
}
