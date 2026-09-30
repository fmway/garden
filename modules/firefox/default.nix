{ den, lib, inputs, ... }: let
  inherit (import "${inputs.den}/nix/lib/entities/_types.nix" { inherit lib den; }) resolvedCtxModule;
  inherit (den.lib) policy;
  allHosts = lib.concatMap builtins.attrValues (builtins.attrValues den.hosts);
  allHomes = lib.concatMap builtins.attrValues (builtins.attrValues den.homes);
  allUsers = lib.concatMap (h: builtins.attrValues h.users) allHosts;
  allFirefoxProfiles = lib.concatMap (p: builtins.attrNames p.firefox-profiles) (allUsers ++ allHomes);

  browsers = {
    firefox   = { };
    floorp    = { };
    librewolf = { };
    zen-browser.getModule = { user, ... }: let
      variant = user.zen-browser.variant or "beta";
    in inputs.zen-browser.homeModules.${variant} or (
      throw "den: zen-browser variant '${variant}' not found in inputs.zen-browser.homeModules"
    );
  };

  allBrowserClasses = builtins.attrNames browsers;

  profileForward =
    { host, user, firefox-profile, ... }:
    den._.forward {
      each = builtins.concatMap (from: [
        { inherit from; class = from; }
      ] ++ map (class:
        { inherit from class; }
      ) (firefox-profile.classAliases.${from} or [])) firefox-profile.classes;
      fromClass = item: item.class;
      intoClass = _: "homeManager";
      intoPath = item: [ "programs" item.from "profiles" firefox-profile.profileName ];
      fromAspect = _: firefox-profile.resolved;
      adaptArgs = { pkgs, config, ... }: item: {
        inherit pkgs;
        homeConfig = config;
        browserConfig = config.programs.${item.from};
        config = config.programs.${item.from}.profiles.${firefox-profile.profileName};
      };
    };

  policyFn =
    home-or-user:
    { user, host, ... }:
      builtins.concatMap (firefox-profile: [
        (policy.include (profileForward { inherit host user firefox-profile; }))
      ] ++ map (class:
        policy.include {
          homeManager = {
            programs.${class}.enable = lib.mkDefault true;
            imports = [
              ((browsers.${class}.getModule or (_: { })) { inherit host user; })
            ];
          };
         }
      ) firefox-profile.classes) (builtins.attrValues (home-or-user.firefox-profiles or { }));

  firefoxProfileType = { user, host, ... }: den.lib.schema.mkInstanceType den.schema.firefox-profile {
    strict = false;
    extraModules = [
      (resolvedCtxModule "firefox-profile")
      ({ config, name, ... }: {
        config._module.args.host = host;
        config._module.args.user = user;
        config._module.args.firefox-profile = config;
        options = {
          host = lib.mkOption {
            default = host;
          };
          user = lib.mkOption {
            default = user;
          };
          firefox-profile = lib.mkOption {
            default = config;
          };
          profileName = lib.mkOption {
            type = lib.types.str;
            description = "Profile name used in home-manager (defaults to the attrset key).";
            default = name;
          };
          classes = lib.mkOption {
            type = lib.types.listOf (lib.types.enum allBrowserClasses);
            description = ''
              Browser classes to enable for this profile.
              Each class maps to homeManager.programs.<class>.profiles.<profileName>.

              Built-in (no extra inputs needed): firefox, floorp, librewolf
              External (needs inputs.zen-browser): zen-browser
            '';
            default = [ "firefox" ];
          };
          classAliases = lib.mkOption {
            # No submodule / enum allBrowserClasses, user might be want to add another classes
            type = lib.types.attrsOf (lib.types.listOf lib.types.str);
            description = ''
              Map a browser class to additional source classes whose content
              is merged in when resolving that class.

              Useful when you want to reuse config written for one browser
              (e.g. `firefox`) as the base for another (e.g. `zen`):

                den.hosts.x86_64-linux.igloo.users.tux.firefox-profiles.tux = {
                  classes = [ "firefox" "zen" ];
                  # zen also collects firefox class content as its base
                  classAliases.zen = [ "firefox" ];
                };

              The aliased classes are resolved from the same aspect and merged
              (via lib.recursiveUpdate) before the target class content is applied,
              so the target class always wins on conflicts.
            '';
            default = { };
            defaultText = lib.literalExpression "{ }";
            example = lib.literalExpression ''{ zen = [ "firefox" ]; }'';
          };
          aspect = lib.mkOption {
            description = "Aspect that configures this profile (defaults to den.aspects.<name>).";
            type = lib.types.raw;
            defaultText = "den.aspects.<name>";
            readOnly = true;
            default = den.aspects.${config.name};
          };
        };
      })
    ];
  };
  firefox-options = { lib, user, ... }: {
    options.firefox-profiles = lib.mkOption {
      type = lib.types.attrsOf (firefoxProfileType { user = user; host = user.host; });
      default = {};
    };
  };
in {
  den.aspects = lib.genAttrs allFirefoxProfiles (_: { });
  den.classes = lib.genAttrs allBrowserClasses  (_: { });

  den.schema = rec {
    firefox-profile.isEntity = true;
    firefox-profile.includes = [ den.default ];
    user.imports = [ firefox-options ];
    # Activate the user-to-firefox-profiles policy via den.schema.user.includes.
    user.includes = [
      { __isPolicy = true; name = "user-to-firefox-profiles"; fn = { user, host, ... }: policyFn user { inherit user host; }; }
    ];

    # for standalone home-manager
    home.imports = user.imports;
    home.includes = [
      { __isPolicy = true; name = "home-to-firefox-profiles"; fn = { home, ... }: policyFn home { inherit (home) user host; }; }
    ];
  };
}
