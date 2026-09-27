import Std

/-!
Executable mathematical model of ChaCha20-Poly1305-PSIV.

Compiled and kernel-checked with Lean 4.32.1; see docs/VERIFICATION.md.
The Rust runtime is a separate implementation, not generated from this file.

The state layout follows the authors' Rust reference. `Nat` arithmetic, lists,
eager vector states, and equality here are deliberately specification-oriented;
compiled code from this model is NOT a constant-time implementation.
-/
namespace PSIV

abbrev Bytes := List UInt8
abbrev State := Vector UInt32 16

def maxMessage : Nat := 65536
def maxAD : Nat := 65536

def loadLE (bs : Bytes) : Nat :=
  bs.foldr (fun b n => b.toNat + 256 * n) 0

def storeLE (value length : Nat) : Bytes :=
  (List.range length).map (fun i => UInt8.ofNat (value / (256 ^ i) % 256))

def byteAt (bs : Bytes) (i : Nat) : UInt8 := (bs.drop i).headD 0

def rotateLeft (x : UInt32) (n : UInt32) : UInt32 :=
  (x <<< n) ||| (x >>> (32 - n))

def quarterRound (s : State) (a b c d : Fin 16) : State :=
  let a₁ := s[a] + s[b]
  let d₁ := rotateLeft (s[d] ^^^ a₁) 16
  let c₁ := s[c] + d₁
  let b₁ := rotateLeft (s[b] ^^^ c₁) 12
  let a₂ := a₁ + b₁
  let d₂ := rotateLeft (d₁ ^^^ a₂) 8
  let c₂ := c₁ + d₂
  let b₂ := rotateLeft (b₁ ^^^ c₂) 7
  Vector.ofFn fun i => if i == a then a₂ else if i == b then b₂
           else if i == c then c₂ else if i == d then d₂ else s[i]

def doubleRound (s : State) : State :=
  let s := quarterRound s 0 4 8 12
  let s := quarterRound s 1 5 9 13
  let s := quarterRound s 2 6 10 14
  let s := quarterRound s 3 7 11 15
  let s := quarterRound s 0 5 10 15
  let s := quarterRound s 1 6 11 12
  let s := quarterRound s 2 7 8 13
  quarterRound s 3 4 9 14

def wordIndices : List (Fin 16) :=
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]

def chachaCore (input : Bytes) : Bytes :=
  let initial : State := Vector.ofFn fun i => UInt32.ofNat (loadLE ((input.drop (4*i.val)).take 4))
  let final := (List.range 10).foldl (fun s _ => doubleRound s) initial
  wordIndices.flatMap (fun i => storeLE ((final[i] + initial[i]).toNat) 4)

inductive Domain where
  | hashKey | tag | encryption
  deriving DecidableEq, Repr

def domainBytes : Domain → Bytes
  | .hashKey => [3, 12, 48, 192]
  | .tag => [5, 10, 80, 160]
  | .encryption => [6, 9, 96, 144]

def domainKey (key : Bytes) (domain : Domain) : Bytes :=
  let k := byteAt key
  let d := byteAt (domainBytes domain)
  [k 0, k 1, k 2, d 0, k 4, k 5, k 6, d 1,
   k 8, k 9, k 10, d 2, k 3, k 7, k 11, d 3] ++ (key.drop 12).take 20

def clamp (key : Bytes) : Bytes :=
  (List.range 16).map fun i =>
    let b := byteAt key i
    if i == 3 || i == 7 || i == 11 || i == 15 then b &&& 15
    else if i == 4 || i == 8 || i == 12 then b &&& 252 else b

def blocks16 (bs : Bytes) : List Bytes :=
  (List.range ((bs.length+15)/16)).map (fun i => (bs.drop (16*i)).take 16)

/-- Mathematical accumulator transition, shared with the refinement boundary. -/
def polyStep (r acc : Nat) (block : Bytes) : Nat :=
  ((acc + loadLE block + 2^(8*block.length))*r) % (2^130-5)

/-- Generic raw Poly1305; on the AEAD encoding all blocks have length 16. -/
def poly1305 (key message : Bytes) : Bytes :=
  let r := loadLE (clamp key)
  let s := loadLE ((key.drop 16).take 16)
  let h := (blocks16 message).foldl
    (polyStep r) 0
  storeLE ((h+s) % (2^128)) 16

def pad16 (bs : Bytes) : Bytes :=
  bs ++ List.replicate ((16 - bs.length % 16) % 16) 0

def encode (ad message : Bytes) : Bytes :=
  pad16 ad ++ pad16 message ++ storeLE ad.length 8 ++ storeLE message.length 8

structure Context where
  polyKey : Bytes
  tagKey : Bytes
  encKey : Bytes
  deriving Repr

/-- Low-level model setup. Public `init` checks the key length. -/
def setup (key : Bytes) : Context :=
  { polyKey := (chachaCore (domainKey key .hashKey ++ List.replicate 28 0)).take 32
    tagKey := domainKey key .tag
    encKey := domainKey key .encryption }

def init (key : Bytes) : Except String Context :=
  if key.length == 32 then .ok (setup key) else .error "key must have 32 bytes"

def makeTag (ctx : Context) (nonce ad message : Bytes) : Bytes :=
  let digest := poly1305 ctx.polyKey (encode ad message)
  (chachaCore (ctx.tagKey ++ nonce ++ digest)).take 16

/-- Total XOR: if the stream is short, remaining message bytes are unchanged.
For actual PSIV the generated stream always covers the whole message. -/
def xorBytes : Bytes → Bytes → Bytes
  | [], _ => []
  | x :: xs, [] => x :: xs
  | x :: xs, k :: ks => (x ^^^ k) :: xorBytes xs ks

def keyStream (ctx : Context) (nonce tag : Bytes) (length : Nat) : Bytes :=
  let initial := loadLE (tag.take 8)
  ((List.range ((length+63)/64)).flatMap fun i =>
    chachaCore (ctx.encKey ++ nonce ++ storeLE ((initial+i) % (2^64)) 8 ++
      (tag.drop 8).take 8)).take length

def crypt (ctx : Context) (nonce tag message : Bytes) : Bytes :=
  xorBytes message (keyStream ctx nonce tag message.length)

/-- Detached internals used by the algebraic proof statements. -/
def sealDetached (ctx : Context) (nonce ad message : Bytes) : Bytes × Bytes :=
  let tag := makeTag ctx nonce ad message
  (crypt ctx nonce tag message, tag)

def openDetached (ctx : Context) (nonce ad ciphertext tag : Bytes) : Option Bytes :=
  let candidate := crypt ctx nonce tag ciphertext
  if makeTag ctx nonce ad candidate == tag then some candidate else none

def sealRecord (ctx : Context) (nonce ad message : Bytes) : Except String Bytes :=
  if nonce.length != 12 then .error "nonce must have 12 bytes"
  else if ad.length > maxAD ∨ message.length > maxMessage then .error "record limit exceeded"
  else let (ciphertext, tag) := sealDetached ctx nonce ad message
       .ok (ciphertext ++ tag)

def openRecord (ctx : Context) (nonce ad record : Bytes) : Except String Bytes :=
  if nonce.length != 12 then .error "nonce must have 12 bytes"
  else if ad.length > maxAD ∨ record.length > maxMessage+16 then .error "record limit exceeded"
  else if record.length < 16 then .error "record shorter than tag"
  else
    match openDetached ctx nonce ad (record.take (record.length-16)) (record.drop (record.length-16)) with
    | some message => .ok message
    | none => .error "authentication failed"

/-- Checks format, not secrecy or entropy of the supplied key. -/
def sealKey (key nonce ad message : Bytes) : Except String Bytes := do
  let ctx ← init key
  sealRecord ctx nonce ad message

def openKey (key nonce ad record : Bytes) : Except String Bytes := do
  let ctx ← init key
  openRecord ctx nonce ad record

end PSIV
