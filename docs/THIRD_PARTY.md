# Attribution and third-party components

The construction is from Tim Beyne, Yu Long Chen and Michiel Verbauwhede, [A Robust Variant of ChaCha20-Poly1305](https://eprint.iacr.org/2025/222). The pinned [reference repository](https://github.com/MichielVerbauwhede/ChaCha20-Poly1305-PSIV/tree/b6eec88ccdc75e489e4f4bc90438391c73185c2c) is CC0-1.0; its source/license and adapter provenance are in `vendor/author-reference` within the [complete release archive](../releases/README.md). No author review or endorsement of this package is claimed. Primitive descriptions/KATs come from RFC 8439; local record fixtures are not official PSIV KATs.

The new Rust core depends on Poly1305 0.8.0, subtle 2.6.1 and zeroize 1.9.0. The WASM adapter uses wasm-bindgen 0.2.100 and js-sys 0.3.77. `Cargo.lock` identifies resolved versions; `bindings/wasm/licenses` supplies notices for 34 registry packages including test/build dependencies. The WASM package includes these notices and Rust standard-library attribution. Rust dependency source is downloaded or read from Cargo's cache, not vendored here. Dependencies retain their own licenses.

Lean runtime attribution and licenses remain in `docs/licenses`; Rust runtime attribution is `bindings/wasm/licenses/RUST-COPYRIGHT-library.html`. Lean-generated C remains separate from both the historical handwritten C backend and the new Rust implementation. The main MIT license covers independently authored project code, not third-party components.

Build/test tools include Rust, Lean, LLVM/Clang, Python, Node, npm and TypeScript. Tool executables and caches are excluded from release archives. Earlier C verification tools and logs are historical evidence, not dependencies of the Cargo/Lake library workflow.
