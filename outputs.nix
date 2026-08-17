inputs: let
  lib = inputs.flake-parts.inputs.nixpkgs-lib.lib;
  scanDir = builtins.toPath ./modules;
  genModules = inputs.import-tree
    (self: self.map (p': let
      p = builtins.toPath p';
      h = builtins.head paths;
      t = builtins.tail paths;
      paths = lib.splitString "/" (lib.removePrefix "${scanDir}/" p');
      filename = lib.last t;
      name = if builtins.length t == 1 then lib.removeSuffix ".nix" filename else builtins.head t;
      r = {
        inherit name;
        path = p';
        is_dep = filename == "deps.nix";
      };
    in if h == "batteries" then r else p))
    (s: s.pipeTo (modules: let
      parts = builtins.partition builtins.isAttrs modules;
      flakeModules = fixModules parts.right;
      allModules = builtins.attrValues flakeModules;
      flakeModule = {
        __functor = _: _: { imports = builtins.concatMap (x: ((x.__functor or (_: _: x)) null null).imports) allModules; };
        with-deps.imports = builtins.concatMap (x: (x.with-deps or x).imports) allModules;
      };
    in { imports = parts.wrong; flake = { inherit flakeModule; flakeModules = flakeModules // { default = flakeModule; }; }; }))
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
  
in inputs.flake-parts.lib.mkFlake { inherit inputs; } {
  imports = [ genModules ];
}
