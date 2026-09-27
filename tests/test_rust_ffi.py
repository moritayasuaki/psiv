"""Public Rust C-ABI and immutable-output regression checks on valid C objects."""
import ctypes as C,json,pathlib,platform
root=pathlib.Path(__file__).resolve().parents[1]
(root/'build/reports').mkdir(parents=True,exist_ok=True)
ext='dylib' if platform.system()=='Darwin' else 'so'
lib=C.CDLL(str(root/f'build/rust/release/libpsiv_rust.{ext}'))
P=C.c_void_p;Z=C.c_size_t;R=C.c_ssize_t
lib.psiv_rs_new.argtypes=[P,Z];lib.psiv_rs_new.restype=P
lib.psiv_rs_free.argtypes=[P]
for name in ['seal','open']:
 f=getattr(lib,'psiv_rs_'+name);f.argtypes=[P,P,Z,P,Z,P,Z,P,Z];f.restype=R
lib.psiv_rs_seal_in_place.argtypes=[P,P,Z,P,Z,P,Z,Z];lib.psiv_rs_seal_in_place.restype=R
lib.psiv_rs_open_in_place.argtypes=[P,P,Z,P,Z,P,Z];lib.psiv_rs_open_in_place.restype=R
count=0
def check(b):
 global count
 assert b;count+=1
vectors=json.loads((root/'tests/vectors-extended.json').read_text())
for v in vectors:
 k,n,a,m,r=[bytes.fromhex(v[f]) for f in ['key','nonce','ad','plaintext','record']]
 ctx=lib.psiv_rs_new(k,32);check(bool(ctx))
 try:
  record=C.create_string_buffer(b'\xa5'*(len(r)+3));out=C.create_string_buffer(b'\xa5'*(len(m)+3))
  check(lib.psiv_rs_seal(ctx,n,12,a,len(a),m,len(m),record,len(r))==len(r));check(record.raw[:len(r)]==r);check(record.raw[len(r):]==b'\xa5'*3+b'\0')
  check(lib.psiv_rs_open(ctx,n,12,a,len(a),r,len(r),out,len(m))==len(m));check(out.raw[:len(m)]==m)
  for i in range(len(m),len(r)):
   bad=bytearray(r);bad[i]^=1;before=out.raw
   check(lib.psiv_rs_open(ctx,n,12,a,len(a),bytes(bad),len(bad),out,len(m))==-2);check(out.raw==before)
  inplace=C.create_string_buffer(r,len(r));
  check(lib.psiv_rs_open_in_place(ctx,n,12,a,len(a),inplace,len(r))==len(m));check(inplace.raw[:len(m)]==m)
  check(lib.psiv_rs_seal_in_place(ctx,n,12,a,len(a),inplace,len(m),len(r))==len(r));check(inplace.raw==r)
  inplace[len(r)-1]=bytes([r[-1]^1]);before=inplace.raw
  check(lib.psiv_rs_open_in_place(ctx,n,12,a,len(a),inplace,len(r))==-2);check(inplace.raw==before)
 finally:lib.psiv_rs_free(ctx)
key=bytes(32);nonce=bytes(12);ctx=lib.psiv_rs_new(key,32);b=C.create_string_buffer(b'x'*80,80)
try:
 before=b.raw
 check(lib.psiv_rs_seal(ctx,nonce,12,None,0,b,32,b,80)==-5)
 check(lib.psiv_rs_seal(ctx,nonce,12,None,0,b,32,C.byref(b,1),79)==-5)
 check(lib.psiv_rs_seal(ctx,nonce,11,None,0,b,32,b,80)==-1)
 check(lib.psiv_rs_seal(None,nonce,12,None,0,b,32,b,80)==-1)
 check(lib.psiv_rs_open(ctx,nonce,12,None,0,b,15,None,0)==-6)
 check(lib.psiv_rs_seal(ctx,nonce,12,None,0,None,1,b,80)==-1)
 check(lib.psiv_rs_seal(ctx,nonce,12,None,0,b,32,b,47)==-4)
 check(lib.psiv_rs_seal_in_place(ctx,nonce,12,None,0,b,65,80)==-4)
 check(b.raw==before)
 # Empty spans accept null, including an empty authenticated plaintext result.
 tag=C.create_string_buffer(16)
 check(lib.psiv_rs_seal(ctx,nonce,12,None,0,None,0,tag,16)==16)
 check(lib.psiv_rs_open(ctx,nonce,12,None,0,tag,16,None,0)==0)
 check(not lib.psiv_rs_new(None,32));check(not lib.psiv_rs_new(key,31))
 lib.psiv_rs_free(None)
finally:lib.psiv_rs_free(ctx)
report={'status':'PASS','records':len(vectors),'checks':count,'scope':'Rust C ABI on actual valid objects, lengths, overlap and unchanged error output; not a universal FFI memory-safety proof'}
(root/'build/reports/rust-ffi-tests.json').write_text(json.dumps(report,indent=2)+'\n');print(report)
