import PSIV.Hex

def main (args : List String) : IO UInt32 := do
  match args with
  | [op, key, nonce, ad, message] =>
    match runVector op key nonce ad message with
    | .ok output => IO.println (hex output); return 0
    | .error error => IO.eprintln error; return 1
  | _ =>
    IO.eprintln "Development-only usage: psiv_lean seal|open KEYHEX NONCEHEX ADHEX DATAHEX"
    return 2
