# Verification scope

This repository contains a Lean specification and a separate Rust implementation. **There is no full Rust-to-Lean equivalence proof, compiled constant-time proof or production-security qualification.** The proofs, tests and boundaries below are public so that users can inspect and reproduce the evidence.

## Reproducible checks

[GitHub CI](https://github.com/moritayasuaki/psiv/actions/workflows/ci.yml) runs `scripts/build.sh --ffi`, `scripts/check.sh --ffi` and `scripts/package.sh` on Ubuntu 24.04 and macOS 14. Check the run for the commit you use; a passing older run does not validate a later change. Toolchains and dependencies are pinned.

| Check | Scope |
|---|---|
| Lean build, axiom audit and kernel replay | 36 theorem declarations; only `propext`, `Classical.choice` and `Quot.sound` are allowed; no `sorryAx` or native-evaluation axioms |
| Separate Lake consumer | Imports and executes the typed specification API |
| Rust debug/release tests and Clippy | Boundaries, padding, maximum lengths, counter wrap, authentication failures and unchanged output on errors |
| Shared Lean/Rust records | 278 records, 1,112 observations per backend: seal, open, corrupted tag and wrong nonce |
| Node.js WebAssembly tests | 9,734 assertions covering shared records, tampering, errors and session lifecycle |
| Optional Rust C ABI tests | 12,245 checks and a plain C consumer; valid-object overlap, lengths, capacity and failure preservation |
| Package builds | Standalone Cargo source crate and npm package with WASM and notices |

The [build guide](BUILD.md) explains local reproduction. Fresh reports go to `.local/reports/`; CI uploads them as artifacts. An additional [browser consumer](../examples/browser/index.html) checks 278 records manually. Bare-metal compilation, TypeScript consumer checks and structural LLVM validation are optional checks, not jobs in the CI matrix.

Fixtures are local research vectors, not official PSIV validation vectors. Finite agreement with the Lean model does not establish equivalence for all inputs. The source attribution and pinned construction reference are in [THIRD_PARTY.md](THIRD_PARTY.md).

## What the Lean proofs establish

The model proves XOR/stream and encryption/decryption roundtrips, typed-library properties, selected natural-number limb identities, and injectivity of a branch-trace encoding. The theorem statements in `PSIV/` determine their exact assumptions and scope.

`PSIV.ConstantTime` proves properties of a mathematical trace representation. It does not model execution of Rust or machine code. The limb lemmas do not verify the opaque state of the RustCrypto Poly1305 implementation. The [refinement boundary](REFINEMENT.md) identifies the missing links.

## What remains unproved

- **Functional equivalence:** initialization, ChaCha state packing, the selected Poly1305 backend, incremental authentication, stream operations and error contracts need a compositional proof against Lean.
- **Constant-time execution:** `subtle` tag comparison and fixed-operation source code do not prove branch/address noninterference of compiled code. CPU multiplication timing, compiler transformations and WASM engines need explicit assumptions and analysis. Input lengths, validation status and authentication outcome are public.
- **Memory and erasure guarantees:** the Rust core forbids unsafe code and allocates no heap memory, but dependencies and adapters have additional obligations. Zeroization does not prove removal of every secret copy, register or physical trace. See [safety contracts](SAFETY.md).
- **Production qualification:** independent review, protocol-specific per-key usage limits, nonce/replay policy, supported target profiles and key lifecycle requirements remain open.

The current Rust pipeline does not include Miri, sanitizer, fuzz or statistical timing jobs. Historical checks of a different C implementation are not evidence for the Rust runtime. No external audit or endorsement is implied.
