import PSIV.Model
/-! Development vector CLI ONLY: arguments appear in process listings.
Do not pass real secret keys here. Use c/linux_cli.c's file interface instead.
This parser is shared by the compiled development CLIs. -/
open PSIV

def nibble (c : Char) : Except String Nat :=
  if '0' ≤ c ∧ c ≤ '9' then .ok (c.toNat - '0'.toNat)
  else if 'a' ≤ c ∧ c ≤ 'f' then .ok (c.toNat - 'a'.toNat + 10)
  else if 'A' ≤ c ∧ c ≤ 'F' then .ok (c.toNat - 'A'.toNat + 10)
  else .error "invalid hexadecimal character"

def parseHexChars (cs : List Char) : Except String Bytes := go cs [] where
  go : List Char → Bytes → Except String Bytes
    | [], acc => .ok acc.reverse
    | [_], _ => .error "hex string has odd length"
    | a :: b :: rest, acc => do
      let x ← nibble a
      let y ← nibble b
      go rest (UInt8.ofNat (16*x+y) :: acc)

def hex (bs : Bytes) : String :=
  let digits := "0123456789abcdef".toList
  String.ofList (bs.flatMap fun b =>
    [(digits.drop (b.toNat / 16)).headD '0', (digits.drop (b.toNat % 16)).headD '0'])

def runVector (op key nonce ad message : String) : Except String Bytes := do
  let k ← parseHexChars key.toList
  let n ← parseHexChars nonce.toList
  let a ← parseHexChars ad.toList
  let m ← parseHexChars message.toList
  if op == "seal" then sealKey k n a m
  else if op == "open" then openKey k n a m
  else .error "operation must be seal or open"
