{
  lib,
  typst,
  dockerTools,
  ...
}:
dockerTools.buildImage {
  name = "typst";
  tag = "latest";
  copyToRoot = [ typst ];
  config = {
    Cmd = [ (lib.getExe typst) ];
  };
}
