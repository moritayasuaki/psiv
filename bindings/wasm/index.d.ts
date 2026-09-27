/** Experimental Rust-backed PSIV. No production-security/compiled-CT guarantee. */
export interface Session {
  /** Return ciphertext || 16-byte tag. Inputs are unchanged. */
  seal(nonce: Uint8Array, ad: Uint8Array, plaintext: Uint8Array): Uint8Array;
  /** Authenticate before returning plaintext; throws on failure. Inputs unchanged. */
  open(nonce: Uint8Array, ad: Uint8Array, record: Uint8Array): Uint8Array;
  /** Erase retained Rust context and release it. Idempotent. */
  destroy(): void;
}
/** Snapshot the caller's 32-byte key and initialize the bundled Rust WASM module. */
export function createSession(key: Uint8Array): Promise<Session>;
export const KEY_BYTES: 32;
export const NONCE_BYTES: 12;
export const TAG_BYTES: 16;
export const MAX_MESSAGE: 65536;
export const MAX_AD: 65536;
