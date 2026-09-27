/* Experimental Rust PSIV ABI. Full Lean refinement/constant-time proof pending. */
#ifndef PSIV_RUST_H
#define PSIV_RUST_H
#include <stddef.h>
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
#define PSIV_RS_KEY_BYTES 32u
#define PSIV_RS_NONCE_BYTES 12u
#define PSIV_RS_TAG_BYTES 16u
#define PSIV_RS_MAX_MESSAGE 65536u
#define PSIV_RS_MAX_AD 65536u
#define PSIV_RS_VERSION "0.5.0-experimental"
typedef struct psiv_rs_context psiv_rs_context;
enum { PSIV_RS_INVALID=-1, PSIV_RS_AUTH=-2, PSIV_RS_LIMIT=-3,
       PSIV_RS_CAPACITY=-4, PSIV_RS_OVERLAP=-5, PSIV_RS_LENGTH=-6 };
/* Returns an owned opaque handle, or NULL for invalid key length/null.
 * No ownership of key transfers. Free a nonnull result exactly once.
 * Allocation failure follows Rust's allocator policy (normally process abort). */
psiv_rs_context *psiv_rs_new(const uint8_t *key,size_t key_len);
void psiv_rs_free(psiv_rs_context *ctx);
/* Functions return bytes written (including zero), or a negative status.
 * All errors preserve caller output. Record format is ciphertext || tag.
 * Every nonempty span must describe live accessible objects. NULL is permitted
 * only for empty spans. Handles must come from psiv_rs_new and remain live.
 * Concurrent readers are allowed; freeing requires exclusive ownership.
 * Output must be disjoint from context, nonce, AD, and input. Use the dedicated
 * in-place functions for exact input/output aliasing; partial overlap is invalid.
 * No call may race with mutation of its inputs. Raw pointer validity cannot be
 * checked by this interface. The safe Rust crate is preferred from Rust code. */
ptrdiff_t psiv_rs_seal(const psiv_rs_context*,const uint8_t*,size_t,
    const uint8_t*,size_t,const uint8_t*,size_t,uint8_t*,size_t);
ptrdiff_t psiv_rs_open(const psiv_rs_context*,const uint8_t*,size_t,
    const uint8_t*,size_t,const uint8_t*,size_t,uint8_t*,size_t);
/* Encrypt plaintext_len bytes in buffer; capacity includes room for the tag. */
ptrdiff_t psiv_rs_seal_in_place(const psiv_rs_context*,const uint8_t*,size_t,
    const uint8_t*,size_t,uint8_t *buffer,size_t plaintext_len,size_t capacity);
/* On success only the returned prefix is plaintext; the old tag remains. */
ptrdiff_t psiv_rs_open_in_place(const psiv_rs_context*,const uint8_t*,size_t,
    const uint8_t*,size_t,uint8_t *record,size_t record_len);
#ifdef __cplusplus
}
#endif
#endif
