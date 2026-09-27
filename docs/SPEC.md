# Implemented byte-level specification

This document defines the byte layout implemented by the Lean model and Rust core.
The pinned author reference below provides construction provenance. Local shared
fixtures check interoperability; they are not a security proof or official validation vectors.

## References

- [Pinned author main.rs](https://github.com/MichielVerbauwhede/ChaCha20-Poly1305-PSIV/blob/b6eec88ccdc75e489e4f4bc90438391c73185c2c/implementation/src/main.rs)
- [Pinned author helper_functions.rs](https://github.com/MichielVerbauwhede/ChaCha20-Poly1305-PSIV/blob/b6eec88ccdc75e489e4f4bc90438391c73185c2c/implementation/src/helper_functions.rs)

See [VERIFICATION.md](VERIFICATION.md) and [REFINEMENT.md](REFINEMENT.md) for the scope of the public tests and proofs.

## Core

Read 16 little-endian UInt32 words. Apply 10 ChaCha double rounds with the usual
16,12,8,7 rotations and column/diagonal schedules. Add each original state word
modulo 2^32 and serialize little-endian. This is a 64-byte input/output function;
its input is NOT the standard RFC 8439 key/nonce layout.

## Domain encoding

For key bytes k[0..31], form a 36-byte prefix:

```
k0 k1 k2 d0  k4 k5 k6 d1  k8 k9 k10 d2  k3 k7 k11 d3  k12 ... k31
```

The four domain bytes (hex) are:

| Purpose | d0 | d1 | d2 | d3 |
|---|---|---|---|---|
| Poly1305 key derivation | 03 | 0c | 30 | c0 |
| Synthetic tag | 05 | 0a | 50 | a0 |
| Encryption | 06 | 09 | 60 | 90 |

Append nonce[12], counter[8], rest[8], giving 64 bytes total. The two 8-byte fields
are simply the digest halves for tag generation. In encryption the first is a
little-endian UInt64 counter, initialized to tag[0..7], and the second is tag[8..15].
Only the low 64-bit counter is incremented, with modulo 2^64 wrap as in the authors'
`wrapping_add`. This is not a 128-bit increment.

## Session setup

```
poly_key = Core(DomainKey(key, hash_key) || zero[28])[0..31]
tag_prefix = DomainKey(key, tag)
enc_prefix = DomainKey(key, encryption)
```

Poly1305's r is clamped in the ordinary way. The Rust context caches its Poly1305 key state, plus tag_prefix and enc_prefix. The Lean context caches the corresponding
byte strings. Context serialization is not an API.

## Per-record seal

```
encoded = AD || pad_to_16(AD) || M || pad_to_16(M)
          || LE64(length(AD)) || LE64(length(M))
H = Poly1305(poly_key, encoded)
T = Core(tag_prefix || nonce || H)[0..15]
C = M XOR stream(enc_prefix, nonce, T)
record = C || T
```

Padding contributes zero bytes only when needed; a multiple-of-16 input does not
receive an extra padding block. Each actual Poly1305 block carries its implicit
high 1 bit. Lengths are byte counts, not bit counts. All tags are 16 bytes.

## Open

Recover candidates with the supplied tag, recompute H and T on the candidate,
and accept only if all 16 bytes of T match. The Rust implementation does this in
64-byte private blocks before a second decryption pass writes authenticated
plaintext. Candidate plaintext is never returned through the public output on a
failed authentication. Rust tag comparison uses `subtle`;
compiled constant-time behavior has not been proved.

The implementation caps both AD and plaintext at 65,536 bytes. This does not
establish a per-key query/forgery budget. No protocol header or nonce is serialized
by the library itself.
