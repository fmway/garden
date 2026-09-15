{
  outputs = inputs: import ./outputs.nix inputs;

  inputs.import-tree.url = "github:denful/import-tree/4ebb10ae17d5f1ad366e7aef5b92cb8eecf24f69";
}
