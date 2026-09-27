export const KEY_BYTES=32, NONCE_BYTES=12, TAG_BYTES=16, MAX_MESSAGE=65536, MAX_AD=65536;
function bytes(x,name) {if(!(x instanceof Uint8Array))throw new TypeError(`${name} must be Uint8Array`);}
export function makeFactory(load) {
  return async function createSession(key) {
    bytes(key,'key');if(key.length!==KEY_BYTES)throw new RangeError('key must be 32 bytes');
    // Snapshot before awaiting module loading; the caller may reuse its buffer.
    const copy=new Uint8Array(key);
    try {
      const Constructor=await load();
      let raw=new Constructor(copy);
      function call(open,nonce,ad,data) {
        if(!raw)throw new Error('Session was destroyed');
        bytes(nonce,'nonce');bytes(ad,'AD');bytes(data,'data');
        if(nonce.length!==NONCE_BYTES)throw new RangeError('nonce must be 12 bytes');
        if(ad.length>MAX_AD || data.length>(open?MAX_MESSAGE+TAG_BYTES:MAX_MESSAGE))throw new RangeError('PSIV record limit exceeded');
        if(open && data.length<TAG_BYTES)throw new RangeError('invalid PSIV record length');
        try {return open?raw.open(nonce,ad,data):raw.seal(nonce,ad,data);}
        catch(e){throw e instanceof Error?e:new Error(String(e));}
      }
      return Object.freeze({
        seal:(nonce,ad,message)=>call(false,nonce,ad,message),
        open:(nonce,ad,record)=>call(true,nonce,ad,record),
        destroy:()=>{if(raw){const owned=raw;raw=null;try{owned.destroy();}finally{owned.free();}}}
      });
    } finally {copy.fill(0);}
  };
}
