import init,{Session} from './generated/psiv_wasm.js';
import {makeFactory} from './session.mjs';
export {KEY_BYTES,NONCE_BYTES,TAG_BYTES,MAX_MESSAGE,MAX_AD} from './session.mjs';
let loading;
export const createSession=makeFactory(()=>{
  if(!loading)loading=init().then(()=>Session).catch(error=>{loading=undefined;throw error;});
  return loading;
});
