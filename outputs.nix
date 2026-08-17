inputs: let
  scanDir = builtins.toPath ./modules;
  i = builtins.stringLength scanDir + 1;
  genFlake = inputs.import-tree
    (self: self.map (p: let
      t = builtins.tail paths;
      # equivalent with lib.splitString "/"
      paths = builtins.filter builtins.isString (builtins.split "/" (builtins.substring i (-1) p));
      filename = builtins.elemAt paths (builtins.length paths - 1);
      name =
        if t == [ ] then # if <file>.nix, then name = <file>
          builtins.substring 0 (builtins.stringLength filename - 4) filename
        else builtins.head paths; # otherwise name = dirname
    in {
      inherit name;
      path = p;
      is_dep = filename == "deps.nix";
    }))
    (s: s.pipeTo (modules: let
      flakeModules = fixModules modules;
      allModules = builtins.attrValues flakeModules;
      mkModuleFor = name: {
        __functor = _: _: {
          key = "garden:fmway:${name}";
          imports = map (x: x.${name} or x) allModules;
        };
        without = excludes: let
          fModules = removeAttrs flakeModules excludes;
        in {
          key = "garden:fmway:{${builtins.concatStringsSep "," (builtins.attrNames fModules)}}:${name}";
          imports = map (x: x.${name} or x) (builtins.attrValues fModules);
        };
      };
      flakeModule = {
        __functor = self: _: self.base;
        full = mkModuleFor "full" // {
          no-deps-for = list: {
            key = "garden:fmway:full";
            imports = map (name: let m = flakeModules.${name}; in if builtins.elem name list then m.base or m else m.full or m) (builtins.attrNames flakeModules);
          };
        };
        base = mkModuleFor "base";
        without = flakeModule.base.without;
      };
    in { inherit flakeModule; flakeModules = flakeModules // { default = flakeModule; }; }))
  scanDir;

  fixModules = list: let
    grouped = builtins.groupBy (x: x.name) list;
  in builtins.mapAttrs (name: it: let
    parts = builtins.partition (x: x.is_dep) it;
    depModules = map (x: x.path) parts.right;
    baseModules = map (x: x.path) parts.wrong;
    depification = {
      __functor = self: _: self.base;
      full = {
        key = "garden:fmway:${name}:full";
        imports = depModules ++ [ depification.base ];
      };
      base = {
        key = "garden:fmway:${name}:base";
        imports = baseModules;
      };
    };
  in if depModules == [] then depification.base else depification) grouped;
  
in genFlake
