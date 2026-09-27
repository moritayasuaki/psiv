#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ffi=false
if [[ "${1:-}" == "--ffi" ]]; then ffi=true; shift; fi
if [[ $# != 0 ]]; then echo "usage: $0 [--ffi]" >&2; exit 2; fi
mkdir -p build/reports
cargo fmt --all -- --check
cargo test --locked -p psiv
cargo test --locked --release -p psiv
cargo clippy --locked --workspace --all-targets -- -D warnings
cargo run --locked --release --manifest-path examples/rust/Cargo.toml
lake build
python3 scripts/audit_lean.py
lake env leanchecker --verbose PSIV > build/reports/leanchecker.log 2>&1
(cd examples/lean && lake build && .lake/build/bin/psiv_spec_example)
python3 tests/test_lean.py
python3 tests/test_rust_lean.py
node tests/test_rust_wasm.mjs
if $ffi; then
  python3 tests/test_rust_ffi.py
  mkdir -p build/consumer
  case "$(uname -s)" in
    Darwin) cc bindings/c/examples/example.c -I bindings/c/include -L build/rust/release -lpsiv_rust -Wl,-rpath,"$PWD/build/rust/release" -o build/consumer/plain-c;;
    Linux) cc bindings/c/examples/example.c -I bindings/c/include -L build/rust/release -lpsiv_rust -Wl,-rpath,"$PWD/build/rust/release" -o build/consumer/plain-c;;
    *) exit 2;;
  esac
  build/consumer/plain-c
fi
