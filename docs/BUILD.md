# Build and check

The project uses Cargo and Lake. Install Rust through rustup and Lean through elan; their versions are pinned to Rust 1.98.1 and Lean 4.32.1. Full checks also need Python 3 and Node.js 22. CI uses Node 22.22.3 on Ubuntu 24.04 and macOS 14.

```sh
rustup target add wasm32-unknown-unknown
cargo install --locked --version 0.2.100 wasm-bindgen-cli
./scripts/build.sh
./scripts/check.sh
./scripts/package.sh
```

Run build before check or package. Set `WASM_BINDGEN=/path/to/wasm-bindgen` to select an existing CLI, or `CARGO_NET_OFFLINE=true` when dependencies are already cached. Packages are written locally; these commands do not publish anything.

## Rust

```sh
cargo build --locked --release -p psiv
cargo test --locked -p psiv
cargo run --locked --manifest-path examples/rust/Cargo.toml
```

Applications can depend on `rust/psiv` through Cargo. The example is a separate consumer workspace. `scripts/package.sh` also builds and verifies a standalone source crate.

## Lean

`lake build` builds the proof library and the development CLIs in `examples/cli`. The reusable import is `PSIV.Library`. A separate consumer can be run with:

```sh
cd examples/lean
lake exe psiv_spec_example
```

Lean's executable model is for specification and testing; it is not a constant-time backend.

## WebAssembly

The build creates a self-contained package in `.local/wasm/`, including generated WASM, JavaScript loaders, TypeScript declarations and license notices. Source templates remain in `bindings/wasm/`. Import `.local/wasm/node.mjs` directly, or install the npm tarball from `.local/packages/`. See the [WASM guide](../bindings/wasm/README.md).

To exercise the browser consumer, serve the repository on localhost and open `/examples/browser/`. It checks 278 shared fixtures. The [TypeScript example](../examples/wasm-consumer.mts) can be compiled in an application with the package installed using `tsc --strict --target es2022 --module nodenext`.

## Optional C ABI

```sh
./scripts/build.sh --ffi
./scripts/check.sh --ffi
```

This builds the Rust-backed plain C interface in `.local/native/rust-<arch>-<os>/`, and tests it through Python and a plain C consumer. It requires a C compiler. The [header](../bindings/c/include/psiv_rust.h) specifies pointer and lifetime obligations.

## Optional target and LLVM checks

The core is `no_std`. For `x86_64-unknown-none`, the checked-in Cargo configuration selects upstream Poly1305's scalar backend because the pinned compiler failed in AVX2 code generation for this target. Downstream bare-metal consumers need the same setting or `RUSTFLAGS='--cfg poly1305_force_soft'`. This target has been compiled, not executed.

```sh
rustup target add x86_64-unknown-none
cargo build --locked --release -p psiv --target x86_64-unknown-none
cargo rustc --locked --release -p psiv -- --emit=llvm-ir,llvm-bc,asm
python3 scripts/verify_rust_llvm.py .local/rust/release/deps/psiv-<hash>.bc
```

Replace `<hash>` with the generated filename. The LLVM check requires rustc's matching LLVM shared library; `RUST_LLVM_LIBRARY` can select it. It validates module structure, not functional equivalence or constant-time behavior.

## Local files and CI

All project-managed outputs and internal material live under the ignored `.local/` directory:

| Path | Contents |
|---|---|
| `.local/rust/`, `.local/lake/`, `.local/lean-consumer/` | Compiler caches |
| `.local/wasm/`, `.local/native/` | Generated libraries |
| `.local/packages/` | Cargo and npm distribution archives |
| `.local/reports/` | Fresh verification results and logs |
| `.local/history/` | Maintainer-only historical material, if present |

`build.sh` creates ignored `.lake` symlinks to keep Lake's fixed cache paths inside `.local/`. A direct `lake build` before the script may create a normal `.lake/` cache instead; the script preserves any existing cache. Neither form is committed. Put local notes and internal evidence in `.local/`, and never force-add that directory.

GitHub CI builds all interfaces, checks proofs and public APIs, and packages the libraries. It retains verification and package artifacts for 14 days. Actions are pinned, the Lean installer is checksum-verified, and repository permissions are read-only. [CI results](https://github.com/moritayasuaki/psiv/actions/workflows/ci.yml) apply to the recorded commit and do not establish cryptographic security.
