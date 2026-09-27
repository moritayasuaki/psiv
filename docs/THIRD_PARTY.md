# Attribution and third-party components

ChaCha20-Poly1305-PSIV is from Tim Beyne, Yu Long Chen and Michiel Verbauwhede, [*A Robust Variant of ChaCha20-Poly1305*](https://eprint.iacr.org/2025/222). The [authors' reference implementation](https://github.com/MichielVerbauwhede/ChaCha20-Poly1305-PSIV/tree/b6eec88ccdc75e489e4f4bc90438391c73185c2c), pinned to commit `b6eec88ccdc75e489e4f4bc90438391c73185c2c`, is licensed CC0-1.0. This package is independently maintained; no author review or endorsement is claimed. Primitive descriptions and test vectors also use [RFC 8439](https://www.rfc-editor.org/rfc/rfc8439). Local PSIV record fixtures are research vectors, not official validation vectors.

The Rust core uses Poly1305 0.8.0, subtle 2.6.1 and zeroize 1.9.0. The WASM adapter uses wasm-bindgen 0.2.100 and js-sys 0.3.77. `Cargo.lock` identifies the resolved versions. Dependency source is obtained through Cargo and is not vendored here.

[Dependency notices](../bindings/wasm/licenses/) include registry-package licenses and Rust standard-library attribution. Build and package scripts carry those notices into binary distributions. Lean attribution is retained in [docs/licenses](licenses/). These files remain public because redistributors need them; dependencies retain their own licenses.

The repository's [MIT license](../LICENSE) covers project-authored code, not third-party components. Tool executables, compiler caches and internal logs are not part of the source distribution.
