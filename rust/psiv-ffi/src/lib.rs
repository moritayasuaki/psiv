//! C ABI for the Rust PSIV runtime; unsafe conversion is confined to this crate.
//!
//! Callers must supply live, accessible objects for every nonempty span and a
//! handle returned by this library. Pointers may not be forged, freed, or changed
//! concurrently. Checks catch lengths, nulls and overlaps, not arbitrary pointer
//! validity. No unwinding is permitted across the ABI; release uses panic=abort.
#![deny(unsafe_op_in_unsafe_fn)]
use psiv::{Context, Error};
use std::{mem::size_of, ptr, slice};
const INVALID: isize = -1;
const AUTH: isize = -2;
const LIMIT: isize = -3;
const CAPACITY: isize = -4;
const OVERLAP: isize = -5;
const LENGTH: isize = -6;
fn status(result: Result<usize, Error>) -> isize {
    match result {
        Ok(n) => n as isize,
        Err(Error::Authentication) => AUTH,
        Err(Error::Limit) => LIMIT,
        Err(Error::Capacity) => CAPACITY,
        Err(Error::Length) => LENGTH,
    }
}
fn span(p: *const u8, n: usize) -> bool {
    n <= isize::MAX as usize && (n == 0 || !p.is_null()) && (p as usize).checked_add(n).is_some()
}
fn overlaps(a: *const u8, an: usize, b: *const u8, bn: usize) -> bool {
    if an == 0 || bn == 0 {
        return false;
    }
    let a = a as usize;
    let b = b as usize;
    if a <= b {
        b - a < an
    } else {
        a - b < bn
    }
}
// SAFETY: callers validate lengths/nulls and supply the live-object ABI contract.
unsafe fn bytes<'a>(p: *const u8, n: usize) -> &'a [u8] {
    if n == 0 {
        &[]
    } else {
        unsafe { slice::from_raw_parts(p, n) }
    }
}
unsafe fn bytes_mut<'a>(p: *mut u8, n: usize) -> &'a mut [u8] {
    if n == 0 {
        &mut []
    } else {
        unsafe { slice::from_raw_parts_mut(p, n) }
    }
}
fn handle_ok(ctx: *const Context) -> bool {
    !ctx.is_null() && ctx.is_aligned() && span(ctx.cast(), size_of::<Context>())
}
/// Create an owned key schedule, or return null for invalid key length/null.
/// # Safety
/// `key` must refer to `key_len` readable bytes. The caller retains ownership.
#[no_mangle]
pub unsafe extern "C" fn psiv_rs_new(key: *const u8, key_len: usize) -> *mut Context {
    if key_len != 32 || !span(key, key_len) {
        return ptr::null_mut();
    }
    // SAFETY: caller guarantees a live key; exact length was checked.
    let key: &[u8; 32] = unsafe { bytes(key, 32) }
        .try_into()
        .expect("checked key length");
    Box::into_raw(Box::new(Context::new(key)))
}
/// Destroy an owned handle; null is a no-op. Retained secret material is erased.
/// # Safety
/// A nonnull handle must be live, from psiv_rs_new, and freed exactly once, with
/// no concurrent readers. Foreign code must not inspect its opaque storage.
#[no_mangle]
pub unsafe extern "C" fn psiv_rs_free(ctx: *mut Context) {
    if !ctx.is_null() {
        unsafe {
            drop(Box::from_raw(ctx));
        }
    }
}

#[allow(clippy::too_many_arguments)]
unsafe fn crypt(
    ctx: *const Context,
    nonce: *const u8,
    nonce_len: usize,
    ad: *const u8,
    ad_len: usize,
    input: *const u8,
    input_len: usize,
    out: *mut u8,
    capacity: usize,
    decrypt: bool,
    in_place: bool,
) -> isize {
    if !handle_ok(ctx)
        || nonce_len != 12
        || !span(nonce, 12)
        || !span(ad, ad_len)
        || !span(input, input_len)
    {
        return INVALID;
    }
    let n = if decrypt {
        match input_len.checked_sub(16) {
            Some(n) => n,
            None => return LENGTH,
        }
    } else {
        input_len
    };
    if n > psiv::MAX_MESSAGE || ad_len > psiv::MAX_AD {
        return LIMIT;
    }
    let written = if decrypt { n } else { n + 16 };
    if capacity < written {
        return CAPACITY;
    }
    let borrowed = if in_place && decrypt {
        input_len
    } else {
        written
    };
    if !span(out, borrowed) {
        return INVALID;
    }
    if overlaps(out, borrowed, ctx.cast(), size_of::<Context>())
        || overlaps(out, borrowed, nonce, 12)
        || overlaps(out, borrowed, ad, ad_len)
        || (!in_place && overlaps(out, borrowed, input, input_len))
    {
        return OVERLAP;
    }
    if in_place && !ptr::eq(out.cast_const(), input) {
        return INVALID;
    }
    // SAFETY: validated shapes and disjoint writable span; caller guarantees the
    // handle and spans are live for this call. In-place never makes a shared
    // Rust slice of the input alongside its mutable slice.
    let ctx = unsafe { &*ctx };
    let nonce: &[u8; 12] = unsafe { bytes(nonce, 12) }
        .try_into()
        .expect("checked nonce length");
    let ad = unsafe { bytes(ad, ad_len) };
    if in_place {
        let buffer = unsafe { bytes_mut(out, borrowed) };
        status(if decrypt {
            ctx.open_in_place(nonce, ad, buffer)
        } else {
            ctx.seal_in_place(nonce, ad, buffer, n)
        })
    } else {
        let input = unsafe { bytes(input, input_len) };
        let out = unsafe { bytes_mut(out, borrowed) };
        status(if decrypt {
            ctx.open(nonce, ad, input, out)
        } else {
            ctx.seal(nonce, ad, input, out)
        })
    }
}
/// Seal into disjoint output; returns length or a negative status.
/// # Safety
/// All objects must be live and accessible under the crate-level ABI contract.
#[no_mangle]
pub unsafe extern "C" fn psiv_rs_seal(
    ctx: *const Context,
    nonce: *const u8,
    nonce_len: usize,
    ad: *const u8,
    ad_len: usize,
    msg: *const u8,
    msg_len: usize,
    out: *mut u8,
    capacity: usize,
) -> isize {
    unsafe {
        crypt(
            ctx, nonce, nonce_len, ad, ad_len, msg, msg_len, out, capacity, false, false,
        )
    }
}
/// Open into disjoint output; any failure leaves the output unchanged.
/// # Safety
/// All objects must be live and accessible under the crate-level ABI contract.
#[no_mangle]
pub unsafe extern "C" fn psiv_rs_open(
    ctx: *const Context,
    nonce: *const u8,
    nonce_len: usize,
    ad: *const u8,
    ad_len: usize,
    record: *const u8,
    record_len: usize,
    out: *mut u8,
    capacity: usize,
) -> isize {
    unsafe {
        crypt(
            ctx, nonce, nonce_len, ad, ad_len, record, record_len, out, capacity, true, false,
        )
    }
}
/// Seal in-place, with space for the appended tag.
/// # Safety
/// `buffer` is exclusively writable for `capacity` bytes. Other objects satisfy
/// the ABI contract and may not overlap the borrowed output prefix.
#[no_mangle]
pub unsafe extern "C" fn psiv_rs_seal_in_place(
    ctx: *const Context,
    nonce: *const u8,
    nonce_len: usize,
    ad: *const u8,
    ad_len: usize,
    buffer: *mut u8,
    plaintext_len: usize,
    capacity: usize,
) -> isize {
    unsafe {
        crypt(
            ctx,
            nonce,
            nonce_len,
            ad,
            ad_len,
            buffer,
            plaintext_len,
            buffer,
            capacity,
            false,
            true,
        )
    }
}
/// Authenticate before decrypting the record in-place. The old tag remains.
/// # Safety
/// The record is exclusively writable for record_len bytes and other objects
/// satisfy the ABI contract without overlapping that span.
#[no_mangle]
pub unsafe extern "C" fn psiv_rs_open_in_place(
    ctx: *const Context,
    nonce: *const u8,
    nonce_len: usize,
    ad: *const u8,
    ad_len: usize,
    record: *mut u8,
    record_len: usize,
) -> isize {
    unsafe {
        crypt(
            ctx, nonce, nonce_len, ad, ad_len, record, record_len, record, record_len, true, true,
        )
    }
}
