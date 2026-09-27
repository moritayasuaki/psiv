import {createSession, type Session, TAG_BYTES} from '@psiv/experimental';
const session: Session = await createSession(new Uint8Array(32));
const nonce = new Uint8Array(12);
const plaintext = new Uint8Array([1, 2, 3]);
const record: Uint8Array = session.seal(nonce, new Uint8Array(), plaintext);
if (record.length !== plaintext.length + TAG_BYTES) throw Error('Bad record length');
const recovered = session.open(nonce, new Uint8Array(), record);
if (!recovered.every((v, i) => v === plaintext[i])) throw Error('Roundtrip failed');
session.destroy();
if (false) {
  // @ts-expect-error Key input must be bytes, not a string.
  await createSession('invalid key');
  // @ts-expect-error Records must be bytes.
  session.open(nonce, new Uint8Array(), 'invalid record');
}
console.log('PASS: standalone npm package, exports and strict TypeScript consumer');
