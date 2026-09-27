//! Experimental PSIV encryption, with a separate Lean specification.
//!
//! No allocation or operating system is needed by this crate. All application
//! buffers are supplied by the caller. Authentication failure preserves output,
//! including for in-place operations. See the repository verification report:
//! this Rust implementation is not formally proved equivalent to Lean or
//! proved constant-time on a machine, and is not production-qualified.
#![no_std]
#![forbid(unsafe_code)]
#![warn(missing_docs)]

use poly1305::{
    universal_hash::{KeyInit, UniversalHash},
    Poly1305,
};
use subtle::ConstantTimeEq;
use zeroize::{Zeroize, Zeroizing};

/// PSIV key, in bytes.
pub type Key = [u8; 32];
/// External nonce; supplied separately from the record.
pub type Nonce = [u8; 12];
/// Authentication tag appended to each record.
pub const TAG_BYTES: usize = 16;
/// Engineering record limit, not a cryptographic per-key usage budget.
pub const MAX_MESSAGE: usize = 65_536;
/// Engineering associated-data limit.
pub const MAX_AD: usize = 65_536;
/// Package version; the experimental API has no cross-version ABI promise.
pub const VERSION: &str = env!("CARGO_PKG_VERSION");

/// Public error status. All variants leave caller output unchanged.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Error {
    /// Associated data or plaintext exceeds the configured limit.
    Limit,
    /// A record is shorter than its tag or an in-place length exceeds capacity.
    Length,
    /// Caller output cannot hold the result.
    Capacity,
    /// The supplied record did not authenticate.
    Authentication,
}
impl core::fmt::Display for Error {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        f.write_str(match self {
            Self::Limit => "PSIV record limit exceeded",
            Self::Length => "invalid PSIV record length",
            Self::Capacity => "insufficient PSIV output capacity",
            Self::Authentication => "PSIV authentication failed",
        })
    }
}
impl core::error::Error for Error {}

/// A reusable, immutable key schedule. Drop erases the retained key material.
///
/// No Clone/Debug implementation exposes or encourages copying secret state.
/// The caller still owns, and must manage, its original key. Zeroization cannot
/// promise removal of compiler-generated copies, registers, or physical leakage.
pub struct Context {
    poly: Poly1305,
    tag_key: Zeroizing<[u8; 36]>,
    enc_key: Zeroizing<[u8; 36]>,
}
impl Context {
    /// Cache the three domain-separated keys. This performs no allocation.
    pub fn new(key: &Key) -> Self {
        let mut state = Zeroizing::new([0u8; 64]);
        state[..36].copy_from_slice(&domain_key(key, [3, 12, 48, 192]));
        let derived = Zeroizing::new(core_block(&state));
        Self {
            poly: Poly1305::new(poly1305::Key::from_slice(&derived[..32])),
            tag_key: Zeroizing::new(domain_key(key, [5, 10, 80, 160])),
            enc_key: Zeroizing::new(domain_key(key, [6, 9, 96, 144])),
        }
    }

    /// Write ciphertext followed by a 16-byte tag; return the bytes written.
    /// Bytes after the returned length are untouched.
    pub fn seal(
        &self,
        nonce: &Nonce,
        ad: &[u8],
        plaintext: &[u8],
        out: &mut [u8],
    ) -> Result<usize, Error> {
        check_limits(ad.len(), plaintext.len())?;
        let n = plaintext.len();
        if out.len() < n + TAG_BYTES {
            return Err(Error::Capacity);
        }
        let tag = self.make_tag(nonce, ad, plaintext);
        self.xor_to(nonce, &tag, plaintext, &mut out[..n]);
        out[n..n + TAG_BYTES].copy_from_slice(&tag);
        Ok(n + TAG_BYTES)
    }

    /// Authenticate in private stack storage, then write plaintext.
    /// Authentication failure never releases candidate plaintext to `out`.
    pub fn open(
        &self,
        nonce: &Nonce,
        ad: &[u8],
        record: &[u8],
        out: &mut [u8],
    ) -> Result<usize, Error> {
        let n = record_len(ad.len(), record.len())?;
        if out.len() < n {
            return Err(Error::Capacity);
        }
        let tag = self.authenticate(nonce, ad, record, n)?;
        self.xor_to(nonce, &tag, &record[..n], &mut out[..n]);
        Ok(n)
    }

    /// Encrypt the first `plaintext_len` bytes, appending the tag in the same buffer.
    pub fn seal_in_place(
        &self,
        nonce: &Nonce,
        ad: &[u8],
        buffer: &mut [u8],
        plaintext_len: usize,
    ) -> Result<usize, Error> {
        check_limits(ad.len(), plaintext_len)?;
        if buffer.len() < plaintext_len + TAG_BYTES {
            return Err(Error::Capacity);
        }
        let tag = self.make_tag(nonce, ad, &buffer[..plaintext_len]);
        self.xor_in_place(nonce, &tag, &mut buffer[..plaintext_len]);
        buffer[plaintext_len..plaintext_len + TAG_BYTES].copy_from_slice(&tag);
        Ok(plaintext_len + TAG_BYTES)
    }

    /// Authenticate before changing the buffer. On success the old trailing tag
    /// remains; only the returned prefix is plaintext. On error all bytes survive.
    pub fn open_in_place(
        &self,
        nonce: &Nonce,
        ad: &[u8],
        record: &mut [u8],
    ) -> Result<usize, Error> {
        let n = record_len(ad.len(), record.len())?;
        let tag = self.authenticate(nonce, ad, record, n)?;
        self.xor_in_place(nonce, &tag, &mut record[..n]);
        Ok(n)
    }

    fn finish_tag(
        &self,
        nonce: &Nonce,
        mut hash: Poly1305,
        ad_len: usize,
        msg_len: usize,
    ) -> [u8; 16] {
        let mut lengths = [0u8; 16];
        lengths[..8].copy_from_slice(&(ad_len as u64).to_le_bytes());
        lengths[8..].copy_from_slice(&(msg_len as u64).to_le_bytes());
        hash.update_padded(&lengths);
        let mut digest = hash.finalize();
        let mut state = Zeroizing::new([0u8; 64]);
        state[..36].copy_from_slice(&*self.tag_key);
        state[36..48].copy_from_slice(nonce);
        state[48..].copy_from_slice(&digest);
        digest.as_mut_slice().zeroize();
        let block = Zeroizing::new(core_block(&state));
        let mut tag = [0u8; 16];
        tag.copy_from_slice(&block[..16]);
        tag
    }
    fn make_tag(&self, nonce: &Nonce, ad: &[u8], message: &[u8]) -> [u8; 16] {
        let mut hash = self.poly.clone();
        hash.update_padded(ad);
        hash.update_padded(message);
        self.finish_tag(nonce, hash, ad.len(), message.len())
    }
    fn authenticate(
        &self,
        nonce: &Nonce,
        ad: &[u8],
        record: &[u8],
        n: usize,
    ) -> Result<[u8; 16], Error> {
        let mut tag = [0u8; 16];
        tag.copy_from_slice(&record[n..]);
        let mut hash = self.poly.clone();
        hash.update_padded(ad);
        let mut ctr = load64(&tag[..8]);
        for chunk in record[..n].chunks(64) {
            let mut candidate = self.stream_block(nonce, &tag, ctr);
            for (b, &c) in candidate.iter_mut().zip(chunk) {
                *b ^= c;
            }
            hash.update_padded(&candidate[..chunk.len()]);
            ctr = ctr.wrapping_add(1);
        }
        let expected = Zeroizing::new(self.finish_tag(nonce, hash, ad.len(), n));
        // The authentication decision is a permitted public output.
        if bool::from(tag.ct_eq(&*expected)) {
            Ok(tag)
        } else {
            Err(Error::Authentication)
        }
    }
    fn stream_block(&self, nonce: &Nonce, tag: &[u8; 16], ctr: u64) -> Zeroizing<[u8; 64]> {
        let mut state = Zeroizing::new([0u8; 64]);
        state[..36].copy_from_slice(&*self.enc_key);
        state[36..48].copy_from_slice(nonce);
        state[48..56].copy_from_slice(&ctr.to_le_bytes());
        state[56..].copy_from_slice(&tag[8..]);
        Zeroizing::new(core_block(&state))
    }
    fn xor_to(&self, nonce: &Nonce, tag: &[u8; 16], input: &[u8], out: &mut [u8]) {
        let mut ctr = load64(&tag[..8]);
        for (src, dst) in input.chunks(64).zip(out.chunks_mut(64)) {
            let block = self.stream_block(nonce, tag, ctr);
            for ((d, &s), &k) in dst.iter_mut().zip(src).zip(block.iter()) {
                *d = s ^ k;
            }
            ctr = ctr.wrapping_add(1);
        }
    }
    fn xor_in_place(&self, nonce: &Nonce, tag: &[u8; 16], buffer: &mut [u8]) {
        let mut ctr = load64(&tag[..8]);
        for chunk in buffer.chunks_mut(64) {
            let block = self.stream_block(nonce, tag, ctr);
            for (b, &k) in chunk.iter_mut().zip(block.iter()) {
                *b ^= k;
            }
            ctr = ctr.wrapping_add(1);
        }
    }
}

fn check_limits(ad: usize, msg: usize) -> Result<(), Error> {
    if ad > MAX_AD || msg > MAX_MESSAGE {
        Err(Error::Limit)
    } else {
        Ok(())
    }
}
fn record_len(ad: usize, record: usize) -> Result<usize, Error> {
    let msg = record.checked_sub(TAG_BYTES).ok_or(Error::Length)?;
    check_limits(ad, msg)?;
    Ok(msg)
}
fn load64(bytes: &[u8]) -> u64 {
    let mut b = [0u8; 8];
    b.copy_from_slice(bytes);
    u64::from_le_bytes(b)
}
fn domain_key(key: &Key, domain: [u8; 4]) -> [u8; 36] {
    let mut out = [0u8; 36];
    for i in 0..3 {
        out[4 * i..4 * i + 3].copy_from_slice(&key[4 * i..4 * i + 3]);
        out[4 * i + 3] = domain[i];
    }
    out[12] = key[3];
    out[13] = key[7];
    out[14] = key[11];
    out[15] = domain[3];
    out[16..].copy_from_slice(&key[12..]);
    out
}
fn qr(x: &mut [u32; 16], a: usize, b: usize, c: usize, d: usize) {
    x[a] = x[a].wrapping_add(x[b]);
    x[d] = (x[d] ^ x[a]).rotate_left(16);
    x[c] = x[c].wrapping_add(x[d]);
    x[b] = (x[b] ^ x[c]).rotate_left(12);
    x[a] = x[a].wrapping_add(x[b]);
    x[d] = (x[d] ^ x[a]).rotate_left(8);
    x[c] = x[c].wrapping_add(x[d]);
    x[b] = (x[b] ^ x[c]).rotate_left(7);
}
fn core_block(input: &[u8; 64]) -> [u8; 64] {
    let mut initial = Zeroizing::new([0u32; 16]);
    for (word, bytes) in initial.iter_mut().zip(input.chunks_exact(4)) {
        *word = u32::from_le_bytes([bytes[0], bytes[1], bytes[2], bytes[3]]);
    }
    let mut x = Zeroizing::new(*initial);
    for _ in 0..10 {
        qr(&mut x, 0, 4, 8, 12);
        qr(&mut x, 1, 5, 9, 13);
        qr(&mut x, 2, 6, 10, 14);
        qr(&mut x, 3, 7, 11, 15);
        qr(&mut x, 0, 5, 10, 15);
        qr(&mut x, 1, 6, 11, 12);
        qr(&mut x, 2, 7, 8, 13);
        qr(&mut x, 3, 4, 9, 14);
    }
    let mut out = [0u8; 64];
    for i in 0..16 {
        out[4 * i..4 * i + 4].copy_from_slice(&x[i].wrapping_add(initial[i]).to_le_bytes());
    }
    out
}

#[cfg(test)]
mod tests;
