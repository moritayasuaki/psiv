import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {createSession} from '../.local/wasm/node.mjs';
const vectors=JSON.parse(readFileSync(new URL('./vectors-extended.json',import.meta.url)));
let checks=0;
const bytes=h=>new Uint8Array(Buffer.from(h,'hex'));
for(const v of vectors){
  const s=await createSession(bytes(v.key)),n=bytes(v.nonce),a=bytes(v.ad),m=bytes(v.plaintext),r=bytes(v.record);
  assert.deepEqual(s.seal(n,a,m),r);checks++;
  assert.deepEqual(s.open(n,a,r),m);checks++;
  for(let i=r.length-16;i<r.length;i++){
    const bad=r.slice();bad[i]^=1;const copy=bad.slice();
    assert.throws(()=>s.open(n,a,bad),/authentication failed/i);assert.deepEqual(bad,copy);checks+=2;
  }
  s.destroy();s.destroy();assert.throws(()=>s.open(n,a,r),/destroyed/);checks++;
}
// Prove initialization uses the call-time key, even during async module loading.
const key=new Uint8Array(32),pending=createSession(key);key.fill(0xff);
const s=await pending,control=await createSession(new Uint8Array(32));
const nonce=new Uint8Array(12),empty=new Uint8Array();
assert.deepEqual(s.seal(nonce,empty,empty),control.seal(nonce,empty,empty));checks++;
assert.throws(()=>s.seal(nonce,empty,new Uint8Array(65537)),/limit/);checks++;
assert.throws(()=>s.open(nonce,empty,new Uint8Array(15)),/length/);checks++;
await assert.rejects(createSession(new Uint8Array(31)),/32 bytes/);checks++;
s.destroy();control.destroy();
const report={status:'PASS',record_cases:vectors.length,checks,backend:'Rust psiv crate via wasm-bindgen; no C crypto linked',node:process.version};
mkdirSync(new URL('../.local/reports/',import.meta.url),{recursive:true});
writeFileSync(new URL('../.local/reports/rust-wasm-tests.json',import.meta.url),JSON.stringify(report,null,2)+'\n');
console.log(report);
