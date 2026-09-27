use psiv::{Context, Error};
fn unhex(s: &str) -> Vec<u8> {
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap())
        .collect()
}
#[test]
fn shared_psiv_fixtures() {
    let vectors: serde_json::Value = serde_json::from_str(include_str!("vectors.json")).unwrap();
    for v in vectors.as_array().unwrap() {
        let key: [u8; 32] = unhex(v["key"].as_str().unwrap()).try_into().unwrap();
        let nonce: [u8; 12] = unhex(v["nonce"].as_str().unwrap()).try_into().unwrap();
        let ad = unhex(v["ad"].as_str().unwrap());
        let msg = unhex(v["plaintext"].as_str().unwrap());
        let record = unhex(v["record"].as_str().unwrap());
        let c = Context::new(&key);
        let mut got = vec![0; record.len()];
        c.seal(&nonce, &ad, &msg, &mut got).unwrap();
        assert_eq!(got, record);
        let mut out = vec![0; msg.len()];
        c.open(&nonce, &ad, &record, &mut out).unwrap();
        assert_eq!(out, msg);
        *got.last_mut().unwrap() ^= 1;
        assert_eq!(
            c.open(&nonce, &ad, &got, &mut out),
            Err(Error::Authentication)
        );
        assert_eq!(out, msg);
    }
}
