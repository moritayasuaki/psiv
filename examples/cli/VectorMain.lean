import PSIV.Hex
import PSIV.Refinement

/-! Test-only line protocol. Public deterministic test data only.
Five tab-separated hex fields: operation, key, nonce/limbs, AD/tag, message.
One output line per request: OK:<hex> or ERR:<reason>. -/
open PSIV

def vectorRequest (line : String) : Except String Bytes := do
  match line.splitOn "\t" with
  | [op, k, n, a, m] =>
    if op == "seal" || op == "open" then runVector op k n a m
    else do
      let key ← parseHexChars k.toList
      let nonce ← parseHexChars n.toList
      let ad ← parseHexChars a.toList
      let msg ← parseHexChars m.toList
      match op with
      | "core" => if msg.length == 64 then pure (chachaCore msg) else .error "core length"
      | "poly" => if key.length == 32 then pure (poly1305 key msg) else .error "poly key"
      | "setup" => if key.length == 32 then pure (Refinement.observeSetup key) else .error "setup key"
      | "stream" =>
        if key.length == 32 && nonce.length == 12 && ad.length == 16 then
          pure (crypt (setup key) nonce ad msg)
        else .error "stream lengths"
      | "step" =>
        if key.length == 32 && nonce.length == 40 && msg.length == 16 then
          pure (Refinement.observeStep key nonce msg)
        else .error "step lengths"
      | "finish" =>
        if key.length == 32 && nonce.length == 40 then
          pure (Refinement.observeFinish key nonce)
        else .error "finish lengths"
      | _ => .error "unknown operation"
  | _ => .error "five fields required"

def main : IO UInt32 := do
  let input ← IO.getStdin
  let output ← IO.getStdout
  repeat
    let line ← input.getLine
    if line.isEmpty then break
    let line := line.dropEndWhile (fun c => c == '\n' || c == '\r') |>.toString
    match vectorRequest line with
    | .ok b => output.putStrLn ("OK:" ++ hex b)
    | .error e => output.putStrLn ("ERR:" ++ e)
    output.flush
  return 0
