# Release files

The archives listed below are preserved locally; a Git clone does not include them. No historical ZIP or package-registry release is automatically published. The repository’s CI creates fresh Cargo/npm package artifacts for each successful run.

The active project contains the reusable Lean/Rust/WASM implementation. Historical C sources, generated binaries, old analysis tools and original logs are retained in the complete release archives here.

| File | Contents |
|---|---|
| `psiv-source-v0.5.0-experimental.zip` | Simplified current source layout, ready-to-use WASM and verification evidence; no build caches or legacy binary trees |
| `packages/` | Current reusable Cargo `.crate` and npm `.tgz`, produced by `scripts/package.sh` |
| `psiv-lean-rust-v0.5.0-experimental.zip` | Complete pre-cleanup release, including C history, native/LLVM artifacts, old reports and original scripts |
| `psiv-lean-v0.2.0-experimental.zip` through `v0.4.0` | Earlier releases, kept unchanged |

The complete v0.5 archive has SHA-256 `751038a0a0fba200733523215ade2a4298844b49d1cb5e78f9a1d0a889e86592`. Its contents were checked byte-for-byte against every tracked source before removing duplicate expanded files. Adjacent `.sha256` files identify each ZIP.

To inspect the old C implementation or reproduce its checks, extract the complete archive into a separate directory and follow its original documentation. It restores the original relative paths (`c/`, `vendor/`, `verification/`, `dist/`, `docs/history/`, and old scripts). Do not extract it over the active project.

Source-only distributions do not embed the historical ZIPs or generated package tarballs; keep those release files separately if you need the old evidence or native binaries.
