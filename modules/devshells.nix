{
  perSystem =
    {
      pkgs,
      config,
      ...
    }:
    {
      devShells.default = config.packages.typst.passthru.rustCranePlatform.devShell {
        checks = config.packages.typst.checks;
        inputsFrom = [ config.packages.typst ];

        buildInputs = with config.packages.typst.passthru.rust-toolchain; [
          rust-analyzer
          rust-src
        ];

        env.RUST_SRC_PATH = "${config.packages.typst.passthru.rust-toolchain.rust-src}/lib/rustlib/src/rust/library";

        packages = [
          # A script for quickly running tests.
          # See https://github.com/typst/typst/blob/main/tests/README.md#making-an-alias
          (pkgs.writeShellScriptBin "testit" ''
            cargo test --workspace --test tests -- "$@"
          '')
        ];
      };
    };
}
