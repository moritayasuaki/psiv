# Library safety contracts

The safe Rust core accepts typed keys/nonces and borrowed slices. It allocates no heap memory and forbids unsafe code in its own source. Input lengths and output capacity are checked before writes. On decryption it computes authentication from private temporary blocks, then writes plaintext only after acceptance. In-place APIs preserve the whole input on returned errors and leave the trailing tag after successful open. Release tests also run with overflow checks enabled; protocol counter increments explicitly wrap.

RustCrypto Poly1305, subtle and zeroize are dependencies, with their own trusted implementations. Some dependency backends contain unsafe code. `no_std` and Rust's type system do not prove cryptographic security, absence of panics for every possible implementation defect, or constant-time machine execution.

`Context` has no Debug/Clone implementation and erases retained key fields on drop. Temporary working state is zeroized where explicitly wrapped. This is not a universal erasure theorem: caller-owned keys, compiler-generated copies, registers, swap and physical traces are outside that guarantee.

The optional C ABI confines raw pointer conversion to `rust/psiv-ffi`. Callers must provide live readable/writable spans and a live owned handle from this library. Length/null/overlap/alignment checks do not validate arbitrary addresses or prevent use-after-free and data races. Free exactly once, with no concurrent access. Release allocation failure/panics may abort the process. The header specifies supported aliasing and dedicated in-place calls.

The WASM adapter copies successful results into JavaScript-owned byte arrays and wipes its Rust temporary vectors. `destroy()` releases the retained context; caller-owned JavaScript inputs and output plaintext remain the caller's responsibility. No complete browser/allocator zeroization or constant-time theorem is established.

Limits of 65,536 bytes for plaintext and AD are implementation limits, not security bounds. The protocol still needs key generation, nonce and replay handling, identity/context binding, key rotation and a justified usage budget. This experimental package supplies no RNG or protocol framing beyond the PSIV record.
