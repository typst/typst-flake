{
  inputs,
  ...
}:
{
  imports = [
    inputs.pkgs-by-name-for-flake-parts.flakeModule
    inputs.flake-parts.flakeModules.easyOverlay
  ];

  perSystem =
    { system, config, ... }:
    {
      # Attach the `local` overlay to `pkgs`.
      # The `local` overlay exposes the packages defined in `config.packages`.
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          # Taken from https://github.com/nix-community/fenix
          (
            _: super:
            let
              pkgs = inputs.fenix.inputs.nixpkgs.legacyPackages.${super.system};
            in
            inputs.fenix.overlays.default pkgs pkgs
          )
          # Taken and adapted from https://crane.dev/getting-started.html
          (
            _: super:
            let
              pkgs = inputs.fenix.inputs.nixpkgs.legacyPackages.${super.system};
            in
            {
              craneLib = inputs.crane.mkLib pkgs;
            }
          )
        ];
      };

      # Directory where the `pkgs` are defined.
      pkgsDirectory = ../pkgs;

      # Default package to be used when running `nix run`.
      packages.default = config.packages.typst;

      # Expose all packages defined in `config.packages` as overlays.
      overlayAttrs = config.packages;
    };
}
