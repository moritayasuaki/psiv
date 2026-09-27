import PSIV.Model

/-! Kernel-checked with Lean 4.32.1. Run scripts/build_lean.sh to rebuild and audit.
No `sorry`, new axioms, unsafe declarations, or native_decide are used here.
These statements describe model algebra only. They are NOT a security reduction,
a proof of Poly1305 limb arithmetic, a C refinement proof, or a side-channel proof.
The encoded sealRecord/openRecord and key-level roundtrips are proved below. -/
namespace PSIV

theorem byte_xor_involution (x k : UInt8) : (x ^^^ k) ^^^ k = x := by
  simp [UInt8.xor_assoc]

theorem xorBytes_length (xs ks : Bytes) : (xorBytes xs ks).length = xs.length := by
  induction xs generalizing ks with
  | nil => cases ks <;> rfl
  | cons x xs ih =>
    cases ks with
    | nil => rfl
    | cons k ks => simp only [xorBytes, List.length_cons, ih]

theorem xorBytes_involution (xs ks : Bytes) : xorBytes (xorBytes xs ks) ks = xs := by
  induction xs generalizing ks with
  | nil => cases ks <;> rfl
  | cons x xs ih =>
    cases ks with
    | nil => rfl
    | cons k ks => simp only [xorBytes, byte_xor_involution, ih]

theorem crypt_length (ctx : Context) (nonce tag msg : Bytes) :
    (crypt ctx nonce tag msg).length = msg.length := by
  exact xorBytes_length _ _

theorem crypt_involution (ctx : Context) (nonce tag msg : Bytes) :
    crypt ctx nonce tag (crypt ctx nonce tag msg) = msg := by
  unfold crypt
  rw [xorBytes_length, xorBytes_involution]

/-- Functional correctness of the DETACHED mathematical interface only. -/
theorem detached_roundtrip (ctx : Context) (nonce ad msg : Bytes) :
    let sealed := sealDetached ctx nonce ad msg
    openDetached ctx nonce ad sealed.1 sealed.2 = some msg := by
  simp [sealDetached, openDetached, crypt_involution]

/-- Mismatching computed tags are rejected in the model. Not unforgeability. -/
theorem mismatch_rejected (ctx : Context) (nonce ad ciphertext tag : Bytes)
    (h : (makeTag ctx nonce ad (crypt ctx nonce tag ciphertext) == tag) = false) :
    openDetached ctx nonce ad ciphertext tag = none := by
  simp [openDetached, h]

@[simp] theorem storeLE_length (v n : Nat) : (storeLE v n).length = n := by
  simp [storeLE]

@[simp] theorem chachaCore_length (input : Bytes) : (chachaCore input).length = 64 := by
  simp [chachaCore, wordIndices, storeLE_length]

@[simp] theorem makeTag_length (ctx : Context) (nonce ad msg : Bytes) :
    (makeTag ctx nonce ad msg).length = 16 := by
  simp [makeTag]

theorem sum_replicate_nat (a n : Nat) : (List.replicate n a).sum = n*a := by
  induction n with
  | zero => simp
  | succ n ih => simp [List.replicate_succ, ih, Nat.succ_mul, Nat.add_comm]

theorem keyStream_length (ctx : Context) (nonce tag : Bytes) (n : Nat) :
    (keyStream ctx nonce tag n).length = n := by
  simp [keyStream, List.map_const']
  omega

/-- Encoded public model interface, including limits and tag splitting. -/
theorem record_roundtrip (ctx : Context) (nonce ad msg : Bytes)
    (hn : nonce.length = 12) (ha : ad.length ≤ maxAD) (hm : msg.length ≤ maxMessage) :
    (sealRecord ctx nonce ad msg).bind (openRecord ctx nonce ad) = .ok msg := by
  have hla : ¬ ad.length > maxAD := by omega
  have hlm : ¬ msg.length > maxMessage := by omega
  have hlr : ¬ msg.length + 16 > maxMessage + 16 := by omega
  have hlt : ¬ msg.length + 16 < 16 := by omega
  simp only [sealRecord, hn, bne_self_eq_false, Bool.false_eq_true, ↓reduceIte,
    hla, hlm, or_self, sealDetached, Except.bind]
  unfold openRecord
  simp only [hn, bne_self_eq_false, Bool.false_eq_true, ↓reduceIte,
    List.length_append, crypt_length, makeTag_length, hla, hlr, hlt, or_self,
    Nat.add_sub_cancel]
  rw [List.take_left' (crypt_length _ _ _ _), List.drop_left' (crypt_length _ _ _ _)]
  simp [openDetached, crypt_involution]

theorem key_roundtrip (key nonce ad msg : Bytes)
    (hk : key.length = 32) (hn : nonce.length = 12)
    (ha : ad.length ≤ maxAD) (hm : msg.length ≤ maxMessage) :
    (sealKey key nonce ad msg).bind (openKey key nonce ad) = .ok msg := by
  simpa [sealKey, openKey, init, hk, bind, pure, Except.bind, Except.pure] using record_roundtrip (setup key) nonce ad msg hn ha hm

#print axioms keyStream_length
#print axioms record_roundtrip
#print axioms key_roundtrip
#print axioms byte_xor_involution
#print axioms detached_roundtrip
#print axioms mismatch_rejected
end PSIV
