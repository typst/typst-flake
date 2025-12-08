{ inputs, ... }:
{
  imports = [
    inputs.treefmt-nix.flakeModule
    inputs.git-hooks.flakeModule
  ];

  perSystem = {
    treefmt = {
      projectRootFile = "flake.nix";
      programs = {
        deadnix.enable = true;
        nixfmt.enable = true;
        prettier.enable = true;
      };
      settings = {
        on-unmatched = "warn";
      };
    };
  };
}
