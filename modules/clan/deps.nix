{ config, lib, ... }:
{
  flake-file.inputs.clan-core = {
    url = "https://git.clan.lol/clan/clan-core/archive/main.tar.gz";
    inputs = lib.mkMerge [
      (lib.mkIf (config.flake-file.inputs ? disko) {
        disko.follows = "disko";
      })
      (lib.mkIf (config.flake-file.inputs ? systems) {
        systems.follows = "systems";
      })
      (lib.mkIf (config.flake-file.inputs ? nix-darwin) {
        nix-darwin.follows = "nix-darwin";
      })
      { nixpkgs.follows = "nixpkgs"; flake-parts.follows = "flake-parts"; }
    ];
  };
}
