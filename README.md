# Typst Flake

This repository contains a Nix Flake[^1] for Typst. It exports a Nix package that can build Typst's CLI using the Nix tool. It is compatible at least with the latest Typst release, and should also build the latest commits on Typst's `main` branch. Should any problems or incompatibilities arise, please contribute a fix or open an issue!

## Usage

### Compiling Typst

To build the Flake using its default Typst version (usually the latest release), first ensure Nix is properly installed with Flake support.[^2] Then, simply clone this repository's contents locally, open a terminal there and write the command below:

```sh
nix build .
```

This should output a runnable Typst binary under `result/bin/typst`.

Alternatively, you can build and run in one go with `nix run .`, such as in the sample command below:

```sh
nix run . -- compile /some/path/doc.typ
```

### Compiling a specific Typst commit

To compile another Typst version or commit, you can use `--override-input` when building. Use one of the sample commands below. You can replace `0.13` in the second example with the specific commit or branch you'd like to build.

```sh
# Compile the latest main commit
nix build . --override-input typst github:typst/typst

# Compile a specific branch: 0.13 (release 0.13.1)
nix build . --override-input typst github:typst/typst/0.13

# Compile a specific commit: d60ec29
nix build . --override-input typst github:typst/typst/d60ec29
```

### Development shell

You can use the command below to spawn a development shell. It should contain `rustc` and `cargo` so you can develop Typst as a contributor.

```sh
nix develop .
```

### License

All code in this repository is licensed under Apache-2.0.

[^1]: Flakes (official NixOS Wiki): https://wiki.nixos.org/wiki/Flakes
[^2]: Nix installation guide (official NixOS Wiki): https://wiki.nixos.org/wiki/Nix_Installation_Guide
