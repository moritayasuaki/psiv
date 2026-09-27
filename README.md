# PSIV

Reusable **Rust + Lean 4.32.1** library, with Rust-backed WebAssembly for Node and browsers. Builds use Cargo and Lake.

Experimental: formal Rust–Lean equivalence, compiled constant-time behavior and production security remain unproved. See the [verification report](docs/VERIFICATION.md).

## Get the source

```sh
git clone https://github.com/moritayasuaki/psiv.git
cd psiv
```

Rust and Lean toolchain versions are checked in. The [build guide](docs/BUILD.md) lists prerequisites. CI runs on Linux and macOS; [contribution guidance](.github/CONTRIBUTING.md) and [security reporting](SECURITY.md) are included.

## Use

**Rust:** add a path dependency to your application:

```toml
[dependencies]
psiv = { path = "../psiv/rust/psiv" }
```

The [Rust guide](rust/psiv/README.md) covers the allocation-free `Context` API and in-place operations. `cargo run --manifest-path examples/rust/Cargo.toml` runs a complete example.

**Lean:** use `require psiv from "../psiv"` in Lake, then `import PSIV.Library`. See [the example](examples/lean/Main.lean).

**WebAssembly:** run `./scripts/build.sh` first (or use the packaged CI artifact), then import `bindings/wasm/node.mjs` or `bindings/wasm/browser.mjs`; both expose `createSession(key)`. See the [JavaScript/TypeScript guide](bindings/wasm/README.md).

## Work on the library

```sh
./scripts/build.sh     # Lean, Rust and WebAssembly
./scripts/check.sh     # proofs, shared vectors and API checks
./scripts/package.sh   # reusable Cargo/npm packages in releases/packages/
```

For just the Rust core: `cargo test -p psiv`. For Lean: `lake build`. Tool versions and optional C compatibility are documented in [BUILD.md](docs/BUILD.md).

| Directory | Contents |
|---|---|
| `PSIV/` | Lean specification, typed API and proofs |
| `rust/` | Rust core and adapters |
| `bindings/` | WebAssembly loaders and optional plain C header |
| `examples/`, `tests/` | Consumers and shared vectors |
| `docs/` | Design, safety and verification evidence |
| `scripts/` | Build, check and packaging helpers |
| `releases/` | Packages and preserved historical archives |

Build caches and fresh check output go to `.lake/` and `build/`; optional native artifacts go to `dist/`. Historical C sources, binaries and older proof tooling are indexed in [release archives](releases/README.md). Those local archives and original machine-specific logs are excluded from Git.
