# psiv — ChaCha20-Poly1305-PSIV

PSIV is authenticated encryption designed for nonce-misuse resistance. It uses Poly1305 over the plaintext and associated data to help derive a synthetic tag, then encrypts with a ChaCha20-core stream determined by that tag. The construction is described in [A Robust Variant of ChaCha20-Poly1305](https://eprint.iacr.org/2025/222).

This crate is a reusable, allocation-free `no_std` Rust implementation with a separate Lean 4.32.1 specification. The Rust core forbids unsafe code. This is research software: Rust-to-Lean equivalence, compiled constant-time behavior and production security are not established.

```rust
use psiv::{Context, Error};

fn example() -> Result<(), Error> {
    // Public test values only. Supply an independently generated secret key
    // and a protocol-managed nonce in an application.
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

Use a local Cargo path dependency, for example `psiv = { path = "/path/to/psiv/rust/psiv" }`. This package has not been published to crates.io. The release also includes a standalone `.crate` source archive.

`Context` caches key setup and supports concurrent immutable use. `seal` writes ciphertext followed by a 16-byte tag; nonce and associated data are supplied separately. `seal_in_place` and `open_in_place` support caller-owned buffers. Decryption authenticates in private stack storage before writing plaintext. Every returned error leaves output unchanged. An in-place successful open leaves the old tag beyond the returned plaintext prefix. Output bytes beyond the returned length are otherwise untouched.

Key size: 32 bytes; nonce size: 12 bytes. Plaintext and associated data are each limited to 65,536 bytes. These engineering limits are not a cryptographic per-key usage budget. This PSIV wire format is not ordinary ChaCha20-Poly1305 and is not interchangeable with it. Repeated identical inputs produce identical records.

The implementation uses pinned RustCrypto Poly1305, `subtle` for tag comparison and `zeroize` for retained keys and working storage. Dependencies can contain unsafe code. Zeroization does not establish erasure of every compiler copy, register, caller buffer or physical trace. Poly1305 requires suitable constant-time multiplication on the chosen processor; no universal machine-code proof is provided. Public lengths, validation status and authentication outcome can affect execution.

The [repository](https://github.com/moritayasuaki/psiv) contains the Lean model, kernel-checked theorems and reproducible tests. Finite agreement with Lean is evidence, not a refinement theorem. See the [verification scope](https://github.com/moritayasuaki/psiv/blob/main/docs/VERIFICATION.md) and [refinement boundary](https://github.com/moritayasuaki/psiv/blob/main/docs/REFINEMENT.md).
