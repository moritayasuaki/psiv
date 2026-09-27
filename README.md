# PSIV

**ChaCha20-Poly1305-PSIV is authenticated encryption designed to resist nonce reuse.** It combines the ChaCha20 core and Poly1305 in a synthetic-IV construction: the message and associated data determine an authentication tag, and that tag helps determine the encryption stream.

The construction is described by Tim Beyne, Yu Long Chen and Michiel Verbauwhede in [*A Robust Variant of ChaCha20-Poly1305*](https://eprint.iacr.org/2025/222). Their analysis covers nonce-misuse resistance and key commitment under the paper's stated models and assumptions. This repository provides an independent **Rust implementation, a Lean specification with checked theorems, and WebAssembly bindings**.

**Experimental research software.** The Rust implementation has not been formally proved equivalent to the Lean model, compiled constant-time behavior is unproved, and the library is not production-qualified. See [verification scope](docs/VERIFICATION.md).

## How it works

For each key, PSIV prepares a reusable Poly1305 key and separate domains for tag generation and encryption. For each record:

1. Hash the associated data and plaintext with Poly1305, including padding and lengths.
2. Protect that hash with the ChaCha20 core, the key and the nonce to produce a 16-byte synthetic tag.
3. Encrypt the plaintext with a ChaCha20-core stream determined by the key, nonce and tag.
4. Return the ciphertext followed by the tag. Decryption recomputes and checks the tag before releasing plaintext.

Associated data is authenticated but not encrypted. The nonce and associated data travel separately from the record. The [byte specification](docs/SPEC.md) defines the exact layout and encoding.

PSIV is a distinct construction: it changes the ChaCha state layout and is **not wire-compatible with ordinary ChaCha20-Poly1305**. Nonce-misuse resistance does not hide repeated identical inputs: the same key, nonce, associated data and plaintext produce the same record. Applications still need a nonce policy, replay protection and a key lifecycle.

| Parameter | This library |
|---|---|
| Key | 32 bytes |
| Nonce | 12 bytes |
| Tag / record overhead | 16 bytes |
| Plaintext and associated data | Each at most 65,536 bytes |
| Record | `ciphertext || tag` |

The length caps are implementation limits, not a per-key security budget.

## Use the library

Clone the repository; packages are not yet published to crates.io or npm:

```sh
git clone https://github.com/moritayasuaki/psiv.git
cd psiv
```

### Rust

The core is allocation-free, supports `no_std`, and exposes reusable contexts plus separate-buffer and in-place operations. Add a path dependency from your application:

```toml
[dependencies]
psiv = { path = "../psiv/rust/psiv" }
```

```rust
use psiv::{Context, Error};

fn example() -> Result<(), Error> {
    // Public example values only; applications supply their own secret key and nonce.
    let key = [0u8; 32];
    let nonce = [0u8; 12];
    let context = Context::new(&key);
    let mut record = [0u8; 21];
    let written = context.seal(&nonce, b"header", b"hello", &mut record)?;
    let mut plaintext = [0u8; 5];
    let read = context.open(&nonce, b"header", &record[..written], &mut plaintext)?;
    assert_eq!(&plaintext[..read], b"hello");
    Ok(())
}
```

See the [Rust API guide](rust/psiv/README.md) and [runnable example](examples/rust/src/main.rs).

### WebAssembly

The same Rust core runs in Node.js and browsers, with ES modules and TypeScript declarations. Build with `./scripts/build.sh`, then import `createSession` from `.local/wasm/node.mjs` or `.local/wasm/browser.mjs`. The [WASM guide](bindings/wasm/README.md) covers usage and packaging.

### Lean

Add `require psiv from "../psiv"` to your Lake configuration and `import PSIV.Library`. The [Lean example](examples/lean/Main.lean) uses the typed specification API. The executable model is intended for specification and verification, not constant-time encryption.

## Build and verify

With the prerequisites in the [build guide](docs/BUILD.md):

```sh
./scripts/build.sh    # Lean, Rust and WebAssembly
./scripts/check.sh    # kernel replay, shared vectors and API tests
./scripts/package.sh # local Cargo and npm packages
```

Cargo and Lake toolchains are pinned. [CI](https://github.com/moritayasuaki/psiv/actions/workflows/ci.yml) runs on Linux and macOS. For Rust alone, use `cargo test --locked -p psiv`; optional C ABI support is covered in the build guide.

Read the [verification scope](docs/VERIFICATION.md), [refinement boundary](docs/REFINEMENT.md) and [API safety contracts](docs/SAFETY.md) before relying on any guarantee. To contribute or report an issue, see [Contributing](.github/CONTRIBUTING.md) and [Security](SECURITY.md).

Project code is [MIT-licensed](LICENSE); [third-party notices](docs/THIRD_PARTY.md) describe dependencies and attribution.
