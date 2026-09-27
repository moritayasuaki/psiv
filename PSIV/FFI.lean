import PSIV.Model
/-! Lean-ABI exports, compiled and exercised through examples/lean_ffi.c.
C callers must use Lean's runtime objects and initialize the module correctly.
This is distinct from the portable psiv.h ABI and is not constant time. -/
namespace PSIV

def ofByteArray (a : ByteArray) : Bytes := a.data.toList

def toByteArray (bs : Bytes) : ByteArray :=
  bs.foldl (fun a b => a.push b) ByteArray.empty

/-- Empty result indicates an error; valid ciphertext includes at least a tag. -/
@[export psiv_lean_seal]
def sealABI (key nonce ad msg : ByteArray) : ByteArray :=
  match sealKey (ofByteArray key) (ofByteArray nonce) (ofByteArray ad) (ofByteArray msg) with
  | .ok output => toByteArray output
  | .error _ => ByteArray.empty

/-- Returns a Lean Option; none=error, some empty array=authenticated empty message. -/
@[export psiv_lean_open]
def openABI (key nonce ad record : ByteArray) : Option ByteArray :=
  match openKey (ofByteArray key) (ofByteArray nonce) (ofByteArray ad) (ofByteArray record) with
  | .ok output => some (toByteArray output)
  | .error _ => none
end PSIV
