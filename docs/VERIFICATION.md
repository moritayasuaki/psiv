# Verification report

**v0.5.0-experimental · 2026-09-27 · Lean 4.32.1 · Rust 1.98.1 · ARM64 macOS**

This release implements reusable Lean and Rust libraries, a Rust-backed WebAssembly package and an optional plain C ABI. Cargo and Lake are the primary build systems. **No full Rust/C-to-Lean equivalence, compiled constant-time proof or production-security claim is made.**

| Current check | Result and scope |
|---|---|
| Lean build, theorem axiom audit and kernel replay | PASS from a clean extracted archive; 36 declarations, including 3 new typed-library theorems. Only `propext`, `Classical.choice`, `Quot.sound`; no `sorryAx` or native-evaluation axioms |
| Separate Lake consumer | PASS; imports the library and runs a roundtrip |
| Rust core debug and release tests | PASS; 5 unit tests plus 1 shared-fixture test in each profile; boundaries, maxima, padding, counter wrap, wrong key/nonce/AD/ciphertext, tag tampering and unchanged failure output |
| Lean/Rust comparison | PASS; 278 records, 1,112 observations per backend: seal, open, corrupted tag and wrong nonce |
| Rust format / Clippy | PASS; strict workspace/all-target lint check |
| Standalone Cargo consumer and extracted `.crate` | PASS; consumer executes; independently extracted crate builds and all 6 tests pass |
| Rust WebAssembly in Node 22.22.3 | PASS; 9,734 assertions across 278 records and API/error/lifecycle checks |
| Rust WebAssembly in browser | PASS; 278 records, 1,112 checks in Chromium 154 through the in-app browser |
| Standalone npm package / TypeScript 5.9.3 | PASS; package exports load, strict declarations compile, encryption/decryption executes |
| Optional Rust C ABI | PASS; 12,245 checks across 278 records, valid-object overlap/length/capacity checks and failure preservation; plain C consumer executes |
| Bare-metal `no_std` x86-64 | Release compile PASS with `poly1305_force_soft`; not executed. Default AVX2 dependency code generation trapped with this toolchain, so target-specific Cargo configuration selects the scalar backend |
| Rust LLVM output | Host core IR, bitcode and assembly emitted; `LLVMVerifyModule` PASS using Rust's matching LLVM 22.1.8. This is structural validation of one module, not whole-program proof |

Evidence is under [the verification index](verification/README.md). The browser test records the rendered result and the tested WASM hash. Shared fixture expectations are local research vectors, not official PSIV validation vectors. Error text can differ between Lean and Rust; successful records must match exactly, and both must reject the specified invalid inputs.

The Rust core is `no_std`, requires no allocation and forbids unsafe code in its own source. RustCrypto Poly1305 and other dependencies remain in the trusted implementation base and may use unsafe internals. The C-ABI and WASM adapters add separate memory/lifetime obligations. An immutable context supports reuse; decryption hashes candidate plaintext in private stack blocks and only writes application output after authentication. Rust tests support these properties; they are not universal formal proofs.

## Constant-time and formal boundary

The three new Lean theorems prove typed initialization and roundtrips of the Lean functions. They do not refer to Rust execution. The six older Lean constant-time-module theorems prove a mathematical branch-trace encoding. They do not establish noninterference of Rust or native binaries.

Tag comparison uses `subtle`; ChaCha uses fixed operations and indexes; loops are intended to depend on public lengths. RustCrypto Poly1305 has processor assumptions, including multiplication timing. Authentication outcome and input validation are public and may select execution paths. No Rust taint, assembly-level noninterference, speculative-execution or physical leakage proof has been completed. See [REFINEMENT.md](REFINEMENT.md).

Miri was unavailable on the installed stable toolchain. New Rust ASan/UBSan, fuzzing and statistical timing runs were not performed. Earlier C sanitizer, fuzz, static-analysis and timing results are retained strictly as C evidence. LLVM 21 initially rejected the new LLVM 22 bitcode due to an unknown attribute; verification succeeded with the matching LLVM library. Build-attempt logs are retained without upgrading failed attempts into passes.

## Preserved C evidence and artifacts

The complete v0.5 release archive preserves the historical `c/psiv.c` (SHA-256 `14b3dbfbfd41c34567bd906017d03bcfc5da309f0726315c95e61bc301a3e3b6`), its 55 bounded source-branch proofs, 8 component contracts, LLVM analyses, sanitizer and fuzz results. These were not rerun for the Rust release and do not transfer to Rust. The [release index](../releases/README.md) identifies the unchanged archives and recovery layout.

Native Rust C-ABI artifacts were executed on ARM64 macOS; WASM was executed in Node and a browser. Rust x86 bare-metal output was compiled only. Historical Linux x86-64/AArch64 C artifacts were cross-compiled, not executed. Native/LLVM binaries can be recovered from the complete archive or regenerated; the active directory keeps source and the ready-to-use WASM package.

## Directory cleanup

The current layout preserves cryptographic source and all Lean theorem statements unchanged. Development CLIs moved to `examples/cli`; build helpers are `build.sh`, `check.sh` and `package.sh`. Reports are grouped under `docs/verification`; new runs write under `build/reports`. The historical expanded C and generated-artifact trees were removed only after verifying they were present verbatim in the complete archive. See [the verification index](verification/README.md) for fresh checks of the reorganized project.

## Public repository

The portable summary and proof/test sources are tracked in Git. Original machine-specific logs and archives remain local. GitHub Actions runs the build and check scripts on Linux and macOS and retains new report artifacts. Hosted CI results are separate from the historical local results above.
