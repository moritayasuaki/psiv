# Contributing

Use Rust 1.98.1 and Lean 4.32.1 from the checked-in toolchain files. Install Node 22 and wasm-bindgen-cli 0.2.100, then run:

```sh
./scripts/build.sh --ffi
./scripts/check.sh --ffi
```

For a Rust-only change, `cargo test --locked -p psiv` and `cargo clippy --locked --workspace --all-targets -- -D warnings` provide a quicker iteration loop. Full CI also checks the Lean model, shared vectors, WASM and optional C ABI. See [BUILD.md](../docs/BUILD.md).

Explain the behavior changed and the checks that support it. For cryptographic or proof changes, describe the affected assumptions, encoding, refinement boundary and any new proof obligations. Keep the shared fixture files consistent. Do not replace a missing proof with a new axiom, `sorry`, native-evaluation assumption or a stronger security claim.

Use public test keys and synthetic data in issues and test cases. Report suspected vulnerabilities through [SECURITY.md](../SECURITY.md).

Commit source, tests and documentation. Keep internal notes, local logs, release archives, generated packages and host-specific manifests inside the ignored `.local/` directory. Never force-add it. Build scripts also keep compiler caches there through ignored Lake cache symlinks. CI artifacts are finite test/proof evidence for their recorded commit; they do not establish production security. Rust and npm packages are not automatically published.
