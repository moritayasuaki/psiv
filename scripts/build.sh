#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Set CARGO_NET_OFFLINE=true to use already cached dependencies.
ffi=false
if [[ "${1:-}" == "--ffi" ]]; then ffi=true; shift; fi
if [[ $# != 0 ]]; then echo "usage: $0 [--ffi]" >&2; exit 2; fi
mkdir -p .local/reports .local/lake .local/lean-consumer/lake .local/wasm
# Lake fixes these cache entry-point names. Preserve an existing cache or link
# fresh checkouts into the single ignored local workspace.
if [[ ! -e .lake && ! -L .lake ]]; then ln -s .local/lake .lake; fi
if [[ ! -e examples/lean/.lake && ! -L examples/lean/.lake ]]; then
  ln -s ../../.local/lean-consumer/lake examples/lean/.lake
fi
lake build
cargo build --locked --release -p psiv --example vectors
cargo build --locked --release -p psiv-wasm --target wasm32-unknown-unknown
bindgen=${WASM_BINDGEN:-wasm-bindgen}
if [[ "$("$bindgen" --version)" != "wasm-bindgen 0.2.100" ]]; then
  echo "Use wasm-bindgen-cli 0.2.100 to match Cargo.lock" >&2; exit 2
fi
cp bindings/wasm/*.mjs bindings/wasm/index.d.ts bindings/wasm/package.json bindings/wasm/README.md bindings/wasm/LICENSE .local/wasm/
cp -R bindings/wasm/licenses .local/wasm/
"$bindgen" --target web --out-dir .local/wasm/generated --out-name psiv_wasm .local/rust/wasm32-unknown-unknown/release/psiv_wasm.wasm
python3 scripts/collect_rust_notices.py
if $ffi; then
  cargo build --locked --release -p psiv-ffi
  case "$(uname -m)" in arm64|aarch64) arch=aarch64;; x86_64) arch=x86_64;; *) exit 2;; esac
  case "$(uname -s)" in Darwin) os=macos; ext=dylib;; Linux) os=linux; ext=so;; *) exit 2;; esac
  d=".local/native/rust-$arch-$os"; mkdir -p "$d/include"
  cp .local/rust/release/libpsiv_rust.a ".local/rust/release/libpsiv_rust.$ext" "$d/"
  cp bindings/c/include/psiv_rust.h "$d/include/"
  cp -R .local/wasm/licenses "$d/"
fi
