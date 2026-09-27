fn main() -> Result<(), psiv::Error> {
    let context = psiv::Context::new(&[0; 32]);
    let nonce = [0; 12];
    let mut record = [0; 21];
    let written = context.seal(&nonce, b"header", b"hello", &mut record)?;
    let mut plaintext = [0; 5];
    let read = context.open(&nonce, b"header", &record[..written], &mut plaintext)?;
    assert_eq!(&plaintext[..read], b"hello");
    record[20] ^= 1;
    let before = plaintext;
    assert_eq!(
        context.open(&nonce, b"header", &record, &mut plaintext),
        Err(psiv::Error::Authentication)
    );
    assert_eq!(plaintext, before);
    println!("PASS: standalone Rust consumer and unchanged rejection output");
    Ok(())
}
