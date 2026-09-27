import Std

/-! Exact trace encoding used by the C relational branch harness.
This proves a mathematical encoding property, not C or CPU semantics.
Chronological observations are reversed before this little-endian encoding.
Equal length is essential: [false] and [] both encode as zero. -/
namespace PSIV.ConstantTime

def pack : List Bool → Nat
  | [] => 0
  | b :: bs => (if b then 1 else 0) + 2 * pack bs

theorem packed_append_step (xs : List Bool) (b : Bool) :
    pack (xs ++ [b]).reverse = 2 * pack xs.reverse + (if b then 1 else 0) := by
  simp [List.reverse_append, pack, Nat.add_comm]

theorem pack_lt_pow_length (xs : List Bool) : pack xs < 2 ^ xs.length := by
  induction xs with
  | nil => simp [pack]
  | cons b bs ih =>
    simp only [pack, List.length_cons, Nat.pow_succ]
    cases b <;> simp only [Bool.false_eq_true, ↓reduceIte] <;> omega

theorem pack_injective_at_length (xs ys : List Bool)
    (hlen : xs.length = ys.length) (hpack : pack xs = pack ys) : xs = ys := by
  induction xs generalizing ys with
  | nil => simpa using hlen.symm
  | cons x xs ih =>
    cases ys with
    | nil => simp at hlen
    | cons y ys =>
      have htail : xs.length = ys.length := by simpa using hlen
      cases x <;> cases y <;> simp only [pack, Bool.false_eq_true, ↓reduceIte] at hpack
      · exact congrArg (false :: ·) (ih ys htail (by omega))
      · omega
      · omega
      · exact congrArg (true :: ·) (ih ys htail (by omega))

theorem pack_lt_width (xs : List Bool) (width : Nat) (h : xs.length ≤ width) :
    pack xs < 2 ^ width := by
  exact Nat.lt_of_lt_of_le (pack_lt_pow_length xs) (Nat.pow_le_pow_right (by decide) h)

theorem packed_word_no_collision (xs ys : List Bool) (width : Nat)
    (hx : xs.length ≤ width) (hy : ys.length ≤ width)
    (hlen : xs.length = ys.length)
    (hword : pack xs % 2 ^ width = pack ys % 2 ^ width) : xs = ys := by
  rw [Nat.mod_eq_of_lt (pack_lt_width xs width hx),
      Nat.mod_eq_of_lt (pack_lt_width ys width hy)] at hword
  exact pack_injective_at_length xs ys hlen hword

theorem chronological_trace_no_collision (xs ys : List Bool) (width : Nat)
    (hx : xs.length ≤ width) (hy : ys.length ≤ width)
    (hlen : xs.length = ys.length)
    (hword : pack xs.reverse % 2 ^ width = pack ys.reverse % 2 ^ width) : xs = ys := by
  have heq : xs.reverse = ys.reverse := packed_word_no_collision xs.reverse ys.reverse width
    (by simpa using hx) (by simpa using hy) (by simpa using hlen) hword
  simpa using congrArg List.reverse heq

end PSIV.ConstantTime
