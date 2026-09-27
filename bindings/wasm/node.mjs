import {readFile} from 'node:fs/promises';
import init,{Session} from './generated/psiv_wasm.js';
import {makeFactory} from './session.mjs';
export {KEY_BYTES,NONCE_BYTES,TAG_BYTES,MAX_MESSAGE,MAX_AD} from './session.mjs';
let loading;
export const createSession=makeFactory(()=>{
  if(!loading)loading=readFile(new URL('./generated/psiv_wasm_bg.wasm',import.meta.url))
    .then(bytes=>init({module_or_path:bytes})).then(()=>Session)
    .catch(error=>{loading=undefined;throw error;});
  return loading;
});
