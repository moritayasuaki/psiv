import PSIV.Properties

/-! Reusable typed specification interface. This module contains no Rust FFI.
The Rust implementation is linked by differential observations, not a refinement theorem. -/
namespace PSIV.Library

abbrev Key := Vector UInt8 32
abbrev Nonce := Vector UInt8 12

structure Session where
  private context : Context

def Session.new (key : Key) : Session := ⟨setup key.toList⟩
def Session.seal (session : Session) (nonce : Nonce) (ad message : Bytes) : Except String Bytes :=
  sealRecord session.context nonce.toList ad message
def Session.open (session : Session) (nonce : Nonce) (ad record : Bytes) : Except String Bytes :=
  openRecord session.context nonce.toList ad record

theorem typed_key_init (key : Key) : init key.toList = .ok (Session.new key).context := by
  simp [init, Session.new]

theorem session_roundtrip (session : Session) (nonce : Nonce) (ad message : Bytes)
    (ha : ad.length ≤ maxAD) (hm : message.length ≤ maxMessage) :
    (session.seal nonce ad message).bind (session.open nonce ad) = .ok message := by
  exact record_roundtrip session.context nonce.toList ad message (by simp) ha hm

theorem new_session_roundtrip (key : Key) (nonce : Nonce) (ad message : Bytes)
    (ha : ad.length ≤ maxAD) (hm : message.length ≤ maxMessage) :
    ((Session.new key).seal nonce ad message).bind ((Session.new key).open nonce ad) = .ok message := by
  exact session_roundtrip _ _ _ _ ha hm

end PSIV.Library
