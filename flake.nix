{
  outputs = inputs: import ./outputs.nix inputs;

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    import-tree.url = "github:denful/import-tree";
  };
}
