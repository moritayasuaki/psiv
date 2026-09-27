import PSIV.Refinement

/-! Natural-number arithmetic behind the radix-2^26 C Poly1305 implementation.
These are Lean theorems about explicit arithmetic, not imported CBMC results.
The link from C syntax to these definitions remains an external proof boundary. -/
namespace PSIV.LimbAlgebra

structure Limbs where
  a : Nat
  b : Nat
  c : Nat
  d : Nat
  e : Nat

def B : Nat := 2^26
def P : Nat := 2^130-5

def value (h : Limbs) : Nat := h.a + B*h.b + B^2*h.c + B^3*h.d + B^4*h.e

def convolution (h r : Limbs) : Limbs :=
  ⟨h.a*r.a + 5*(h.b*r.e+h.c*r.d+h.d*r.c+h.e*r.b),
   h.a*r.b+h.b*r.a + 5*(h.c*r.e+h.d*r.d+h.e*r.c),
   h.a*r.c+h.b*r.b+h.c*r.a + 5*(h.d*r.e+h.e*r.d),
   h.a*r.d+h.b*r.c+h.c*r.b+h.d*r.a + 5*h.e*r.e,
   h.a*r.e+h.b*r.d+h.c*r.c+h.d*r.b+h.e*r.a⟩

def highTerms (h r : Limbs) : Nat :=
  (h.b*r.e+h.c*r.d+h.d*r.c+h.e*r.b) +
  B*(h.c*r.e+h.d*r.d+h.e*r.c) +
  B^2*(h.d*r.e+h.e*r.d) + B^3*h.e*r.e

/-- Folding the high convolution coefficients by five removes a multiple of p. -/
theorem convolution_identity (h r : Limbs) :
    value h * value r = value (convolution h r) + P * highTerms h r := by
  simp only [value, convolution, highTerms, B, P]
  grind

theorem convolution_mod (h r : Limbs) :
    value (convolution h r) % P = (value h * value r) % P := by
  rw [convolution_identity]
  simp [Nat.add_mod]

/-- Normalization mirrors the carries in poly_block using unbounded arithmetic. -/
def carry (h : Limbs) : Limbs :=
  let b := h.b + h.a / B
  let c := h.c + b / B
  let d := h.d + c / B
  let e := h.e + d / B
  let a := h.a % B + 5*(e/B)
  ⟨a % B, b % B + a/B, c % B, d % B, e % B⟩

/-- The carry chain removes exactly p times the final top carry. -/
theorem carry_identity (h : Limbs) :
    value h = value (carry h) +
      P * ((h.e + (h.d + (h.c + (h.b + h.a/B)/B)/B)/B)/B) := by
  simp only [value, carry, B, P]
  omega

theorem carry_mod (h : Limbs) : value (carry h) % P = value h % P := by
  rw [carry_identity h]
  simp [Nat.add_mod]

/-- Universal modular multiplication theorem, independent of limb size. -/
theorem multiply_mod (h r : Limbs) :
    value (carry (convolution h r)) % P = (value h * value r) % P := by
  rw [carry_mod, convolution_mod]

/-- A canonical representative is recovered by a single conditional subtraction. -/
theorem reduce_once_general (p n : Nat) (bound : n < 2*p) :
    (if n < p then n else n-p) = n % p := by
  split
  next low => exact (Nat.mod_eq_of_lt low).symm
  next high =>
    have eq : n = (n-p)+p := by omega
    conv => rhs; rw [eq, Nat.add_mod]
    simp only [Nat.mod_self, Nat.add_zero, Nat.mod_mod]
    exact (Nat.mod_eq_of_lt (by omega)).symm


def add (h m : Limbs) : Limbs :=
  ⟨h.a+m.a, h.b+m.b, h.c+m.c, h.d+m.d, h.e+m.e⟩

theorem value_add (h m : Limbs) : value (add h m) = value h + value m := by
  simp only [value, add]
  grind

/-- Conditional bridge to the actual Lean specification, with the block-decoding
obligation stated explicitly instead of being hidden in an axiom. -/
theorem step_refines_polyStep (h r m : Limbs) (block : Bytes)
    (length16 : block.length = 16)
    (decode_block : value m = loadLE block + 2^128) :
    value (carry (convolution (add h m) r)) % P =
      polyStep (value r) (value h % P) block := by
  rw [multiply_mod, value_add, decode_block]
  simp [polyStep, length16, P, Nat.add_mod, Nat.mul_mod, Nat.add_assoc]

/-- The loose C accumulator range permits a single canonical subtraction. -/
theorem loose_value_bound (h : Limbs)
    (ha : h.a < B) (hb : h.b < B+64) (hc : h.c < B)
    (hd : h.d < B) (he : h.e < B) : value h < 2*P := by
  simp only [value, B, P] at *
  omega


def allLe (h : Limbs) (n : Nat) : Prop :=
  h.a ≤ n ∧ h.b ≤ n ∧ h.c ≤ n ∧ h.d ≤ n ∧ h.e ≤ n

def productBound : Nat := (2*B+63)*(B-1)

/-- Conservative coefficient limits used as CBMC carry preconditions. -/
theorem convolution_bounds (h r : Limbs)
    (hh : allLe h (2*B+63)) (hr : allLe r (B-1)) :
    (convolution h r).a ≤ 21*productBound ∧
    (convolution h r).b ≤ 17*productBound ∧
    (convolution h r).c ≤ 13*productBound ∧
    (convolution h r).d ≤ 9*productBound ∧
    (convolution h r).e ≤ 5*productBound := by
  rcases hh with ⟨ha,hb,hc,hd,he⟩
  rcases hr with ⟨ra,rb,rc,rd,re⟩
  have haa := Nat.mul_le_mul ha ra
  have hab := Nat.mul_le_mul ha rb
  have hac := Nat.mul_le_mul ha rc
  have had := Nat.mul_le_mul ha rd
  have hae := Nat.mul_le_mul ha re
  have hba := Nat.mul_le_mul hb ra
  have hbb := Nat.mul_le_mul hb rb
  have hbc := Nat.mul_le_mul hb rc
  have hbd := Nat.mul_le_mul hb rd
  have hbe := Nat.mul_le_mul hb re
  have hca := Nat.mul_le_mul hc ra
  have hcb := Nat.mul_le_mul hc rb
  have hcc := Nat.mul_le_mul hc rc
  have hcd := Nat.mul_le_mul hc rd
  have hce := Nat.mul_le_mul hc re
  have hda := Nat.mul_le_mul hd ra
  have hdb := Nat.mul_le_mul hd rb
  have hdc := Nat.mul_le_mul hd rc
  have hdd := Nat.mul_le_mul hd rd
  have hde := Nat.mul_le_mul hd re
  have hea := Nat.mul_le_mul he ra
  have heb := Nat.mul_le_mul he rb
  have hec := Nat.mul_le_mul he rc
  have hed := Nat.mul_le_mul he rd
  have hee := Nat.mul_le_mul he re
  simp only [convolution, productBound, Nat.mul_assoc]
  omega

end PSIV.LimbAlgebra
