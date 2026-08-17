{
  outputs = inputs: import ./outputs.nix inputs;

  inputs.import-tree.url = "github:denful/import-tree";
}
