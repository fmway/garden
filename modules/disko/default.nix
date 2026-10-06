{ lib, den, ... }: let
  diskoModule = {
    options.mainDisk = lib.mkOption {
      description = "mainDisk for disko (default: null => /dev/sda)";
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };
in {
  den.classes.disko.description = "Disko class";
  den.schema.host.includes = [
    den.policies.disko-to-nixos
  ];

  den.schema.host.imports = [
    diskoModule
  ];

  den.policies.disko-to-nixos = { host, ... }:
    lib.optional (host.class == "nixos")
      (den.lib.policy.route {
        fromClass = "disko";
        intoClass = "nixos";
        path = [ "disko" ];
        guard = { options, ... }: options ? disko;
        adaptArgs = _: {
          mainDisk =
            if isNull (host.mainDisk or null) then
              lib.warn "mainDisk is undefined, use default value (/dev/sda)" "/dev/sda"
            else host.mainDisk;
        };
      });
}
