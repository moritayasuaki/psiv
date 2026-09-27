# Lean / Rust / C refinement boundary

The reference specification is `PSIV/Model.lean`; the reusable typed interface is `PSIV/Library.lean`. The primary runtime is `rust/psiv/src/lib.rs`, with RustCrypto Poly1305 0.8.0. The historical handwritten C implementation is preserved as `c/psiv.c` in the complete release archive. These are separate implementations. **No complete formal equivalence theorem joins them.**

The intended runtime relation associates a Rust `Context` with a Lean `Context` when the two packed tag/encryption keys and the clamped Poly1305 key/pad represent the same bytes derived by `setup`. A complete proof must establish this relation at initialization and preserve it through every call. The Rust Poly1305 field is opaque dependency state: we have not defined a machine-checked decoder or proved this relation for it.

| Boundary | Established | Required formal link |
|---|---|---|
| Typed Lean interface | `typed_key_init`, `session_roundtrip`, `new_session_roundtrip` checked by Lean | No gap within the stated model assumptions; these theorems say nothing about Rust |
| Rust ChaCha and domain packing | Shared records, boundary tests, explicit wrapping arithmetic | Rust semantics for little-endian packing, all quarter rounds, feed-forward and counter increment refine Lean definitions |
| Poly1305 | Pinned library, matching records; earlier Lean natural-limb algebra | Decode each selected RustCrypto backend; prove multiplication, carry, reduction, pad addition, overflow bounds and final byte encoding |
| Incremental authentication | Padding, block and maximum tests | Every sequence of `update_padded` calls, including 64-byte decrypted chunks and the final lengths block, equals Lean `encode` / `poly1305` |
| Stream and record operations | 278-record differential comparison, in-place/guard tests | All admitted lengths, counter wrap, partial blocks, frame conditions and tag placement refine `crypt`, `sealRecord`, `openRecord` |
| Error behavior and release of plaintext | Runtime checks validate before writing; tests cover unchanged output on failure | Universal valid Rust/FFI object, alias, lifetime and API status/frame contracts; prove no candidate plaintext reaches public output |
| Compiled execution | Builds, native/WASM execution, structural LLVM validation | Compiler/dependency/ABI correctness; public-length trace and memory-address noninterference; target instruction-latency assumptions |

A desired functional statement is: for related contexts and identical admitted byte inputs, Rust seal returns exactly Lean's record, and Rust open agrees with Lean on plaintext or authentication rejection. Buffer allocation/capacity errors are runtime-specific and additionally need frame contracts. Finite tests currently support this relation; none asserts it universally.

For a constant-time property, define the permitted leakage first: input lengths, buffer layout, algorithm/backend selection, validation result and the final authentication bit are public. Candidate plaintext and keys remain secret. Then prove equal observations for calls with equal public parameters and authentication outcome, including branches and accessed addresses. Authentication-success-only decryption is permitted only under this explicit leakage policy. Multiplication timing, speculative execution and the WASM engine need their own assumptions or separate analysis.

The earlier C contracts/trace proofs use a different trusted frontend, solver and instrumentation. They are not imported as Lean axioms and cannot certify the Rust source or its dependency backends. The [complete release archive](../releases/README.md) retains its algebra, bounds and outstanding C composition obligations. `leanchecker` replays Lean proof terms with the Lean kernel and trusts imported modules; functional correctness alone does not imply cryptographic security.
