# Security status and outstanding work

This is experimental research software. Current acceptance means the documented builds, tests and scoped Lean theorems pass; it does not mean production qualification.

1. **Functional refinement remains open.** Prove the full Rust runtime and selected Poly1305 backend equivalent to the Lean specification. The preserved C fixed-limb contracts also still lack whole-library composition.
2. **Constant-time behavior remains open.** State a precise public-leakage policy, prove source and compiled branch/address noninterference, justify instruction timing per supported CPU, and assess WASM engines. Source intent and `subtle` are not a machine-code proof. Existing C trace proofs do not transfer to Rust.
3. **Memory and erasure boundaries remain open.** Safe Rust narrows the interface; dependencies, FFI validity, runtime/compiler behavior and secret copies still require review. No universal C-ABI safety or zeroization theorem is claimed.
4. **Cryptographic/deployment qualification remains open.** Obtain independent review of the construction and implementation; derive protocol-specific per-key usage limits, nonce/replay policy and key lifecycle; document supported processors, compiler profiles and update/release process.

The record cap is an engineering choice and does not establish a production usage budget. General-purpose statistical timing, sanitizer and fuzz tests cannot prove security, even when they pass. A production claim should identify an actual deployment profile and independent evidence, rather than transferring confidence from the Lean model or an older implementation.

Machine-readable claims are in `docs/verification/security.json`; scoped results are in `docs/verification/summary.json` and `docs/VERIFICATION.md`. No external audit or endorsement is implied.
