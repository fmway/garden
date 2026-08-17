{ config, lib, ... }:
{
  flake-file.inputs = {
    impermanence.url = "github:nix-community/impermanence";
    impermanence.inputs = lib.mkMerge [
      (lib.mkIf (config.flake-file.inputs ? home-manager) {
        home-manager.follows = "home-manager";
      })
      {
        nixpkgs.follows = "nixpkgs";
      }
    ];
  };
}
