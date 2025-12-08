{
  inputs,
  lib,
  fenix,
  craneLib,
  openssl,
  pkg-config,
  perl,
  installShellFiles,
  ...
}:
let
  version = (lib.importTOML "${inputs.typst}/Cargo.toml").workspace.package.version;

  rustCranePlatform = (
    craneLib.overrideToolchain (fenix.fromManifestFile inputs.rust-manifest).defaultToolchain
  );

  # Typst derivation's args, used within crane's derivation generation
  # functions.
  commonCraneArgs = {
    pname = "typst";
    inherit version;

    src =
      let
        translationsFilter = path: _type: builtins.match ".*txt$" path != null;
        translationsOrCargo =
          path: type: (translationsFilter path type) || (craneLib.filterCargoSources path type);
      in
      lib.cleanSourceWith {
        src = inputs.typst;
        filter = translationsOrCargo;
      };

    strictDeps = true;

    buildInputs = [
      openssl
    ];

    nativeBuildInputs = [
      pkg-config
      openssl.dev
      perl # Necessary to build and vendor OpenSSL
    ];

    env = {
      LD_LIBRARY_PATH = lib.makeLibraryPath [ openssl ];
    };

    cargoExtraArgs = "--locked --features vendor-openssl";
  };

  # Derivation with just the dependencies, so we don't have to keep
  # re-building them.
  cargoArtifacts = craneLib.buildDepsOnly commonCraneArgs;
in
rustCranePlatform.buildPackage (
  commonCraneArgs
  // {
    inherit cargoArtifacts;

    nativeBuildInputs = commonCraneArgs.nativeBuildInputs ++ [
      installShellFiles
    ];

    postInstall = ''
      installManPage crates/typst-cli/artifacts/*.1
      installShellCompletion \
        crates/typst-cli/artifacts/typst.{bash,fish} \
        --zsh crates/typst-cli/artifacts/_typst
    '';

    env = {
      GEN_ARTIFACTS = "artifacts";
      TYPST_COMMIT_SHA = inputs.typst.rev;
      TYPST_VERSION = "${version} (${inputs.self.shortRev or "dirty"})";
    };

    passthru = {
      rust-toolchain = (fenix.fromManifestFile inputs.rust-manifest);
      rustCranePlatform = rustCranePlatform;
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
    };

    meta = {
      mainProgram = "typst";
    };
  }
)
