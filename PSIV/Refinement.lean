import PSIV.Properties

/-! Mathematical observation boundary for a radix-2^26 limb representation.
No Rust/C semantics, compiler correctness, or runtime refinement is asserted here.
Observations use five 64-bit limbs, each encoded little-endian. -/
namespace PSIV.Refinement

def modulus : Nat := 2^130 - 5
def radix : Nat := 2^26

def decodeLimbs (bytes : Bytes) : Nat :=
  ((List.range 5).map fun i => loadLE ((bytes.drop (8*i)).take 8) * radix^i).sum

/-- Relation to the mathematical accumulator; limb bounds are a separate obligation. -/
def AccumulatorRel (limbs : Bytes) (acc : Nat) : Prop :=
  limbs.length = 40 ∧ decodeLimbs limbs % modulus = acc

def observeSetup (key : Bytes) : Bytes :=
  let ctx := setup key
  let r := loadLE (clamp ctx.polyKey)
  ((List.range 5).flatMap fun i => storeLE (r / radix^i % radix) 8) ++
    (ctx.polyKey.drop 16).take 16 ++ ctx.tagKey ++ ctx.encKey

def observeStep (key limbs block : Bytes) : Bytes :=
  storeLE (polyStep (loadLE (clamp key)) (decodeLimbs limbs % modulus) block) 17

def observeFinish (key limbs : Bytes) : Bytes :=
  storeLE ((decodeLimbs limbs % modulus + loadLE ((key.drop 16).take 16)) % 2^128) 16

/-- Moving a carry between adjacent radix-2^26 limbs preserves integer value. -/
theorem carry26_preserves_value (x y : Nat) :
    x % radix + radix * (y + x / radix) = x + radix*y := by
  simp only [radix, Nat.mul_add]
  omega

/-- The top carry folds by five modulo 2^130-5. -/
theorem top_carry_mod (lo hi : Nat) :
    (lo + 2^130 * hi) % modulus = (lo + 5*hi) % modulus := by
  simp [Nat.add_mod, Nat.mul_mod, modulus]

/-- The mathematical transition always returns a canonical accumulator. -/
theorem polyStep_range (r acc : Nat) (block : Bytes) :
    polyStep r acc block < modulus := by
  exact Nat.mod_lt _ (by decide)

#print axioms carry26_preserves_value
#print axioms top_carry_mod
#print axioms polyStep_range
end PSIV.Refinement
