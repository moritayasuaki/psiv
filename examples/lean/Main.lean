import PSIV.Library
open PSIV PSIV.Library

def main : IO Unit := do
  let key : Key := Vector.replicate 32 0
  let nonce : Nonce := Vector.replicate 12 0
  let session := Session.new key
  let message : Bytes := [0, 1, 255, 3]
  match (session.seal nonce [] message).bind (session.open nonce []) with
  | .ok recovered =>
    if recovered == message then IO.println "Reusable Lean specification PASS"
    else throw <| IO.userError "specification mismatch"
  | .error error => throw <| IO.userError error
