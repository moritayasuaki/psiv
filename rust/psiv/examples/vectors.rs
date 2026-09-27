// Test-only line adapter compatible with the Lean and author-reference adapters.
use psiv::Context;
use std::io::{BufRead, Write};
fn unhex(s: &str) -> Option<Vec<u8>> {
    if s.len() % 2 != 0 || !s.is_ascii() {
        return None;
    }
    (0..s.len())
        .step_by(2)
        .map(|i| u8::from_str_radix(&s[i..i + 2], 16).ok())
        .collect()
}
fn main() {
    let mut out = std::io::BufWriter::new(std::io::stdout());
    for line in std::io::stdin().lock().lines() {
        let line = line.unwrap();
        let f: Vec<_> = line.split('\t').collect();
        let result = (|| -> Option<Vec<u8>> {
            if f.len() != 5 {
                return None;
            }
            let k: [u8; 32] = unhex(f[1])?.try_into().ok()?;
            let n: [u8; 12] = unhex(f[2])?.try_into().ok()?;
            let ad = unhex(f[3])?;
            let data = unhex(f[4])?;
            let c = Context::new(&k);
            let len = match f[0] {
                "seal" => data.len().checked_add(16)?,
                "open" => data.len().checked_sub(16)?,
                _ => return None,
            };
            if len > psiv::MAX_MESSAGE + 16 {
                return None;
            }
            let mut b = vec![0; len];
            let size = if f[0] == "seal" {
                c.seal(&n, &ad, &data, &mut b)
            } else {
                c.open(&n, &ad, &data, &mut b)
            }
            .ok()?;
            b.truncate(size);
            Some(b)
        })();
        if let Some(b) = result {
            write!(out, "OK:").unwrap();
            for x in b {
                write!(out, "{x:02x}").unwrap();
            }
            writeln!(out).unwrap();
        } else {
            writeln!(out, "ERR:rejected").unwrap();
        }
        out.flush().unwrap();
    }
}
