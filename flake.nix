{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    typst = {
      url = "github:typst/typst";
      flake = false;
    };

    crane.url = "github:ipetkov/crane";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    rust-manifest = {
      url = "https://static.rust-lang.org/dist/channel-rust-1.91.0.toml";
      flake = false;
    };
  };

  outputs =
    inputs@{
      crane,
      nixpkgs,
      fenix,
      rust-manifest,
      self,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      # Return { name = { system = value; }; ... } (standard flake schema).
      perSystem =
        inputsFunc:
        with builtins;
        let
          systemInputs = listToAttrs (
            map (system: rec {
              name = system;
              value = inputsFunc rec {
                inherit system;
                pkgs = import nixpkgs { inherit system; };
                lib = pkgs.lib;
                self' = value;
              };
            }) systems
          );
        in
        foldl' (
          acc: system:
          acc
          // (mapAttrs (
            name: value: (acc.${name} or { }) // { ${system} = value; }
          ) systemInputs.${system})
        ) { } systems;
    in
    perSystem
      (
        {
          self',
          pkgs,
          lib,
          system,
          ...
        }:
        let
          root = inputs.typst;
          cargoToml = lib.importTOML "${root}/Cargo.toml";

          pname = "typst";
          version = cargoToml.workspace.package.version;

          rust-toolchain = fenix.packages.${system}.fromManifestFile rust-manifest;

          # Crane-based Nix flake configuration.
          # Based on https://github.com/ipetkov/crane/blob/master/examples/trunk-workspace/flake.nix
          craneLib = (crane.mkLib pkgs).overrideToolchain rust-toolchain.defaultToolchain;

          # Typst files to include in the derivation.
          # Here we include Rust files, docs and tests.
          sourcePaths = [
            "Cargo.toml"
            "Cargo.lock"
            "rustfmt.toml"
            "crates"
            "docs"
            "tests"
          ];

          src = lib.sources.cleanSourceWith {
            src = root;

            filter = path: type:
              builtins.any (accepted: lib.strings.hasPrefix "${root}/${accepted}" path) sourcePaths;
          };

          # Typst derivation's args, used within crane's derivation generation
          # functions.
          commonCraneArgs = {
            inherit src pname version;

            buildInputs = [
              pkgs.openssl
            ];

            nativeBuildInputs = [
              pkgs.pkg-config
              pkgs.openssl.dev
              pkgs.perl # Necessary to build and vendor OpenSSL
            ];

            LD_LIBRARY_PATH = lib.makeLibraryPath [ pkgs.openssl ];

            cargoExtraArgs = "--locked --features vendor-openssl";
          };

          # Derivation with just the dependencies, so we don't have to keep
          # re-building them.
          cargoArtifacts = craneLib.buildDepsOnly commonCraneArgs;

          typst = craneLib.buildPackage (
            commonCraneArgs
            // {
              inherit cargoArtifacts;

              nativeBuildInputs = commonCraneArgs.nativeBuildInputs ++ [
                pkgs.installShellFiles
              ];

              postInstall = ''
                installManPage crates/typst-cli/artifacts/*.1
                installShellCompletion \
                  crates/typst-cli/artifacts/typst.{bash,fish} \
                  --zsh crates/typst-cli/artifacts/_typst
              '';

              GEN_ARTIFACTS = "artifacts";
              TYPST_VERSION = cargoToml.workspace.package.version;
              TYPST_COMMIT_SHA = self.shortRev or "dirty";

              meta.mainProgram = "typst";
            }
          );
        in
        {
          formatter = pkgs.nixfmt-tree;

          packages = {
            default = typst;
            typst-dev = self'.packages.default;
          };

          overlayAttrs = builtins.removeAttrs self'.packages [ "default" ];

          apps.default = {
            type = "app";
            program = lib.getExe typst;
          };

          checks = {
            typst-fmt = craneLib.cargoFmt commonCraneArgs;
            typst-clippy = craneLib.cargoClippy (
              commonCraneArgs
              // {
                inherit cargoArtifacts;
                cargoClippyExtraArgs = "--workspace -- --deny warnings";
              }
            );
            typst-test = craneLib.cargoTest (
              commonCraneArgs
              // {
                inherit cargoArtifacts;
                cargoTestExtraArgs = "--workspace";
              }
            );
          };

          devShells.default = craneLib.devShell {
            checks = self'.checks;
            inputsFrom = [ typst ];

            buildInputs = [
              rust-toolchain.rust-analyzer
              rust-toolchain.rust-src
            ];

            RUST_SRC_PATH = "${rust-toolchain.rust-src}/lib/rustlib/src/rust/library";

            packages = [
              # A script for quickly running tests.
              # See https://github.com/typst/typst/blob/main/tests/README.md#making-an-alias
              (pkgs.writeShellScriptBin "testit" ''
                cargo test --workspace --test tests -- "$@"
              '')
            ];
          };
        }
      );
}
