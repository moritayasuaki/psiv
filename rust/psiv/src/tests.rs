extern crate std;
use super::*;
use std::vec;

#[test]
fn boundary_roundtrips_and_unchanged_failure() {
    let c = Context::new(&[0x42; 32]);
    let nonce = [0xa5; 12];
    for n in [
        0, 1, 15, 16, 17, 63, 64, 65, 127, 128, 129, 4095, 4096, 65535, 65536,
    ] {
        for al in [0, 1, 15, 16, 17, 65] {
            let msg = vec![0x3c; n];
            let ad = vec![0x96; al];
            let mut record = vec![0xcc; n + TAG_BYTES + 5];
            assert_eq!(c.seal(&nonce, &ad, &msg, &mut record), Ok(n + TAG_BYTES));
            assert_eq!(&record[n + TAG_BYTES..], &[0xcc; 5]);
            record.truncate(n + TAG_BYTES);
            let mut out = vec![0xdd; n + 5];
            assert_eq!(c.open(&nonce, &ad, &record, &mut out), Ok(n));
            assert_eq!(&out[..n], &msg);
            assert_eq!(&out[n..], &[0xdd; 5]);
            let mut in_place = vec![0; n + TAG_BYTES];
            in_place[..n].copy_from_slice(&msg);
            assert_eq!(
                c.seal_in_place(&nonce, &ad, &mut in_place, n),
                Ok(n + TAG_BYTES)
            );
            assert_eq!(in_place, record);
            assert_eq!(c.open_in_place(&nonce, &ad, &mut in_place), Ok(n));
            assert_eq!(&in_place[..n], &msg);
            for i in n..n + TAG_BYTES {
                let mut bad = record.clone();
                bad[i] ^= 1;
                let before = out.clone();
                assert_eq!(
                    c.open(&nonce, &ad, &bad, &mut out),
                    Err(Error::Authentication)
                );
                assert_eq!(out, before);
                let before = bad.clone();
                assert_eq!(
                    c.open_in_place(&nonce, &ad, &mut bad),
                    Err(Error::Authentication)
                );
                assert_eq!(bad, before);
            }
        }
    }
}
#[test]
fn input_validation_preserves_buffers() {
    let c = Context::new(&[0; 32]);
    let nonce = [0; 12];
    let mut b = [0xa5; 32];
    let original = b;
    assert_eq!(c.seal(&nonce, &[], &[0; 17], &mut b), Err(Error::Capacity));
    assert_eq!(
        c.seal_in_place(&nonce, &[], &mut b, usize::MAX),
        Err(Error::Limit)
    );
    assert_eq!(c.open(&nonce, &[], &[0; 15], &mut b), Err(Error::Length));
    assert_eq!(c.open(&nonce, &[], &[0; 49], &mut b), Err(Error::Capacity));
    assert_eq!(
        c.seal(&nonce, &vec![0; MAX_AD + 1], &[], &mut b),
        Err(Error::Limit)
    );
    assert_eq!(
        c.seal(&nonce, &[], &vec![0; MAX_MESSAGE + 1], &mut b),
        Err(Error::Limit)
    );
    assert_eq!(
        c.open(&nonce, &[], &vec![0; MAX_MESSAGE + TAG_BYTES + 1], &mut b),
        Err(Error::Limit)
    );
    assert_eq!(b, original);
}
#[test]
fn key_nonce_ad_and_ciphertext_changes_are_rejected() {
    let c = Context::new(&[0x1f; 32]);
    let nonce = [2; 12];
    let mut record = [0; 80];
    c.seal(&nonce, b"AD", &[3; 64], &mut record).unwrap();
    let mut out = [0xa5; 64];
    assert_eq!(
        c.open(&[4; 12], b"AD", &record, &mut out),
        Err(Error::Authentication)
    );
    assert_eq!(
        c.open(&nonce, b"AE", &record, &mut out),
        Err(Error::Authentication)
    );
    assert_eq!(
        Context::new(&[5; 32]).open(&nonce, b"AD", &record, &mut out),
        Err(Error::Authentication)
    );
    record[0] ^= 1;
    assert_eq!(
        c.open(&nonce, b"AD", &record, &mut out),
        Err(Error::Authentication)
    );
    assert_eq!(out, [0xa5; 64]);
}
#[test]
fn immutable_context_is_send_sync() {
    fn require<T: Send + Sync>() {}
    require::<Context>();
}
#[test]
fn counter_wrap_uses_wrapping_add() {
    let c = Context::new(&[6; 32]);
    let nonce = [7; 12];
    let tag = [0xff; 16];
    let mut stream = [0; 128];
    c.xor_in_place(&nonce, &tag, &mut stream);
    assert_eq!(&stream[..64], &*c.stream_block(&nonce, &tag, u64::MAX));
    assert_eq!(&stream[64..], &*c.stream_block(&nonce, &tag, 0));
}
