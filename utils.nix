{ lib, ... }: let
  deepMergeList =
    builtins.zipAttrsWith (_: v: let
      f = builtins.head v;
    in
      if builtins.length v == 1 then
        f
      else if builtins.isAttrs f then
        deepMergeList v
      else if builtins.isList f then
        builtins.concatLists v
      else
        lib.last v
    );
in {
  inherit deepMergeList;
}
