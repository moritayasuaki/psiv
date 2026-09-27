# Build and check

Use Cargo and Lake. Tested tools: Lean 4.32.1, Rust/Cargo 1.98.1, wasm-bindgen 0.2.100, Node 22.22.3 and TypeScript 5.9.3 on ARM64 macOS. Toolchains and dependencies are pinned in `lean-toolchain`, `rust-toolchain.toml` and `Cargo.lock`. Install Rust through rustup and Lean through elan before building.

```sh
rustup target add wasm32-unknown-unknown
cargo install --locked --version 0.2.100 wasm-bindgen-cli
./scripts/build.sh
./scripts/check.sh
./scripts/package.sh
```

Set `WASM_BINDGEN=/path/to/wasm-bindgen` to use an existing CLI. Set `CARGO_NET_OFFLINE=true` to use cached dependencies. Checks need Python 3 and Node. Run build before check; the scripts fail if required tools or artifacts are missing. Packages are written to `releases/packages/`; nothing is published remotely.

For only the native Rust core, use `cargo build --locked --release -p psiv`. Applications depend on `rust/psiv` through Cargo. `examples/rust` is a separate consumer workspace. `cargo package --locked -p psiv --allow-dirty` produces a standalone source crate.

For Lean, use `lake build`. The default targets include the proof library and two development CLIs whose source is in `examples/cli`. A separate consumer runs with `(cd examples/lean && lake build && .lake/build/bin/psiv_spec_example)`. The reusable module is `PSIV.Library`; the Lean runtime is not intended as the constant-time encryption backend.

## WebAssembly

`build.sh` generates the bundled WASM and glue under `bindings/wasm/generated`. `package.sh` creates a local npm tarball with dependency notices. See [the WASM guide](../bindings/wasm/README.md).

For browser checks, serve the repository on localhost and open `/examples/browser/`. It compares 278 shared fixtures. The standalone TypeScript example is `examples/wasm-consumer.mts`; compile it in an application with the tarball installed using `tsc --strict --target es2022 --module nodenext`.

## Optional checks and compatibility

`./scripts/build.sh --ffi` also produces the Rust-backed plain C ABI in `dist/rust-<arch>-<os>`. `./scripts/check.sh --ffi` checks it through Python and a plain C consumer. This does not build historical C cryptographic code and requires no C++ wrapper. The header states pointer and lifetime obligations.

The core compiles as `no_std`. The tested Rust compiler traps in Poly1305 AVX2 code generation for `x86_64-unknown-none`, so the repository's target configuration selects the upstream scalar backend. Downstream bare-metal applications must also carry this setting or use `RUSTFLAGS='--cfg poly1305_force_soft'`. The target was compiled, not executed.

```sh
cargo build --locked --release -p psiv --target x86_64-unknown-none
cargo rustc --locked --release -p psiv -- --emit=llvm-ir,llvm-bc,asm
python3 scripts/verify_rust_llvm.py build/rust/release/deps/psiv-<hash>.bc
```

The LLVM check needs rustc's matching LLVM shared library; `RUST_LLVM_LIBRARY` can select it. This only verifies module structure. It is not functional refinement or a constant-time proof.

## Outputs and history

- `build/`: Cargo products, temporary consumers and fresh reports in `build/reports`.
- `.lake/`: Lean build cache, including one inside the Lean consumer.
- `dist/`: optional regenerated native artifacts.
- `docs/verification/`: preserved evidence and current source checksums.
- `releases/`: reusable packages and historical release archives.

`python3 scripts/archive.py` makes a clean source archive, excluding build products and nested archives. It updates `docs/verification/manifest.json` and `SHA256SUMS`. Binary reproducibility across toolchains is not claimed. The [release index](../releases/README.md) explains how to recover older C sources, proof harnesses and binaries.

## GitHub CI

The CI workflow runs on Ubuntu 24.04 and macOS 14 for pushes to `main`, pull requests and manual dispatch. It installs the checked-in toolchain versions, builds all interfaces, runs the existing verification scripts and packages the libraries without publishing them. Fresh reports and installable packages are retained as workflow artifacts for 14 days.

Actions are pinned to verified upstream commits, the Lean installer archive is checksum-verified, checkout credentials are not persisted, and the workflow has read-only repository permissions. This follows [GitHub’s secure-use guidance](https://docs.github.com/en/actions/reference/security/secure-use). CI configuration is not itself a cryptographic security proof.
