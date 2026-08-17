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
      flakeModule = {
        __functor = _: _: { imports = builtins.concatMap (x: ((x.__functor or (_: _: x)) null null).imports) allModules; };
        with-deps.imports = builtins.concatMap (x: (x.with-deps or x).imports) allModules;
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
      __functor = _: _: { imports = baseModules; };
      with-deps.imports = baseModules ++ depModules;
    };
  in if depModules == [] then { imports = baseModules; } else depification) grouped;
  
in genFlake
