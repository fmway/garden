{ den, lib, inputs, ... }: let
  # Assisted by kiro-ai

  inherit (import "${inputs.den}/nix/lib/entities/_types.nix" { inherit lib den; }) resolvedCtxModule;
  inherit (den.lib.aspects.fx.handlers) constantHandler;
  allHosts = lib.concatMap builtins.attrValues (builtins.attrValues den.hosts);
  allHomes = lib.concatMap builtins.attrValues (builtins.attrValues den.homes);
  allUsers = lib.concatMap (h: builtins.attrValues h.users) allHosts;
  allFirefoxProfiles = lib.concatMap (p: builtins.attrNames p.firefox-profiles) (allUsers ++ allHomes);

  builtinBrowserClasses = [ "firefox" "floorp" "librewolf" ];
  externalBrowserClasses = {
    zen-browser.getModule = { user, ... }: let
      variant = user.zen-browser.variant or "beta";
    in inputs.zen-browser.homeModules.${variant} or (
      throw "den: zen-browser variant '${variant}' not found in inputs.zen-browser.homeModules"
    );
  };

  allBrowserClasses = builtinBrowserClasses ++ builtins.attrNames externalBrowserClasses;

  resolveBrowser =
    aspect: class: let
      resolved = den.lib.aspects.resolve class aspect;
      innerModules = lib.concatMap (m: m.imports or [ ]) resolved.imports;
    in lib.mkMerge innerModules;

  mkBrowserProfileInclude =
    { source, class, host, user, ... }:
    den.lib.policy.include {
      name = "firefox-profile/${source.profileName}/${class}";
      homeManager =
        { pkgs, lib, config, osConfig, ... }: let
          aspect = source.resolved // {
            __scopeHandlers = (source.resolved.__scopeHandlers or { }) // constantHandler { inherit pkgs osConfig; homeConfig = config; };
          };
          additionalModule = externalBrowserClasses.${class}.getModule { inherit source host user; };
        in {
          imports = lib.optional (externalBrowserClasses ? ${class}.getModule) additionalModule;
          programs.${class} = {
            enable = lib.mkDefault true;
            profiles.${source.profileName} = lib.mkMerge (map (resolveBrowser aspect) (source.classAliases.${class} or [ ] ++ [ class ]));
          };
        };
    };

  toFirefoxProfiles =
    home-or-user:
    { user, host, ... }: let
      profiles = lib.attrValues (home-or-user.firefox-profiles or { });
    in lib.concatMap (source: map (class: mkBrowserProfileInclude { inherit source class host user; }) source.classes) profiles;

  firefoxProfileType = { user, host, ... }: den.lib.schema.mkInstanceType den.schema.firefox-profile {
    strict = false;
    extraModules = [
      (resolvedCtxModule "firefox-profile")
      ({ config, name, ... }: {
        config._module.args.host = host;
        config._module.args.user = user;
        config._module.args.profile = config;
        options = {
          host = lib.mkOption {
            default = host;
          };
          user = lib.mkOption {
            default = user;
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
  den.aspects = lib.genAttrs allFirefoxProfiles (_: {});
  den.classes = lib.genAttrs allBrowserClasses  (_: {});

  den.schema = rec {
    firefox-profile.isEntity = true;
    firefox-profile.includes = [ den.default ];
    user.imports = [ firefox-options ];
    # Activate the user-to-firefox-profiles policy via den.schema.user.includes.
    user.includes = [
      { __isPolicy = true; name = "user-to-firefox-profiles"; fn = { user, host, ... }: toFirefoxProfiles user { inherit user host; }; }
    ];

    # for standalone home-manager
    home.imports = user.imports;
    home.includes = [
      { __isPolicy = true; name = "home-to-firefox-profiles"; fn = { home, ... }: toFirefoxProfiles home { inherit (home) user host; }; }
    ];
  };
}
