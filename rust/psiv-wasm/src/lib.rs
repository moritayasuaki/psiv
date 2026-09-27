//! WebAssembly interface; all cryptographic operations use the safe Rust core.
use psiv::{Context, Error};
use wasm_bindgen::prelude::*;
use zeroize::Zeroizing;
fn error(e: Error) -> JsValue {
    JsValue::from_str(&e.to_string())
}
#[wasm_bindgen]
pub struct Session {
    inner: Option<Context>,
}
#[wasm_bindgen]
impl Session {
    #[wasm_bindgen(constructor)]
    pub fn new(key: Vec<u8>) -> Result<Session, JsValue> {
        let key = Zeroizing::new(key);
        let key: &[u8; 32] = key
            .as_slice()
            .try_into()
            .map_err(|_| JsValue::from_str("key must be 32 bytes"))?;
        Ok(Session {
            inner: Some(Context::new(key)),
        })
    }
    pub fn seal(
        &self,
        nonce: Vec<u8>,
        ad: Vec<u8>,
        message: Vec<u8>,
    ) -> Result<js_sys::Uint8Array, JsValue> {
        let nonce = Zeroizing::new(nonce);
        let ad = Zeroizing::new(ad);
        let message = Zeroizing::new(message);
        let ctx = self
            .inner
            .as_ref()
            .ok_or_else(|| JsValue::from_str("Session was destroyed"))?;
        let nonce: &[u8; 12] = nonce
            .as_slice()
            .try_into()
            .map_err(|_| JsValue::from_str("nonce must be 12 bytes"))?;
        if ad.len() > psiv::MAX_AD || message.len() > psiv::MAX_MESSAGE {
            return Err(error(Error::Limit));
        }
        let mut out = Zeroizing::new(vec![0; message.len() + 16]);
        ctx.seal(nonce, &ad, &message, &mut out).map_err(error)?;
        // Copy into a JS-owned array before erasing the Rust allocation.
        Ok(js_sys::Uint8Array::from(out.as_slice()))
    }
    pub fn open(
        &self,
        nonce: Vec<u8>,
        ad: Vec<u8>,
        record: Vec<u8>,
    ) -> Result<js_sys::Uint8Array, JsValue> {
        let nonce = Zeroizing::new(nonce);
        let ad = Zeroizing::new(ad);
        let record = Zeroizing::new(record);
        let ctx = self
            .inner
            .as_ref()
            .ok_or_else(|| JsValue::from_str("Session was destroyed"))?;
        let nonce: &[u8; 12] = nonce
            .as_slice()
            .try_into()
            .map_err(|_| JsValue::from_str("nonce must be 12 bytes"))?;
        let n = record
            .len()
            .checked_sub(16)
            .ok_or_else(|| error(Error::Length))?;
        if ad.len() > psiv::MAX_AD || n > psiv::MAX_MESSAGE {
            return Err(error(Error::Limit));
        }
        let mut out = Zeroizing::new(vec![0; n]);
        ctx.open(nonce, &ad, &record, &mut out).map_err(error)?;
        Ok(js_sys::Uint8Array::from(out.as_slice()))
    }
    pub fn destroy(&mut self) {
        self.inner.take();
    }
}
