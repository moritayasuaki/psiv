#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Set CARGO_NET_OFFLINE=true to use already cached dependencies.
ffi=false
if [[ "${1:-}" == "--ffi" ]]; then ffi=true; shift; fi
if [[ $# != 0 ]]; then echo "usage: $0 [--ffi]" >&2; exit 2; fi
mkdir -p build/reports
lake build
cargo build --locked --release -p psiv --example vectors
cargo build --locked --release -p psiv-wasm --target wasm32-unknown-unknown
bindgen=${WASM_BINDGEN:-wasm-bindgen}
if [[ "$("$bindgen" --version)" != "wasm-bindgen 0.2.100" ]]; then
  echo "Use wasm-bindgen-cli 0.2.100 to match Cargo.lock" >&2; exit 2
fi
"$bindgen" --target web --out-dir bindings/wasm/generated --out-name psiv_wasm build/rust/wasm32-unknown-unknown/release/psiv_wasm.wasm
if $ffi; then
  cargo build --locked --release -p psiv-ffi
  case "$(uname -m)" in arm64|aarch64) arch=aarch64;; x86_64) arch=x86_64;; *) exit 2;; esac
  case "$(uname -s)" in Darwin) os=macos; ext=dylib;; Linux) os=linux; ext=so;; *) exit 2;; esac
  d="dist/rust-$arch-$os"; mkdir -p "$d/include"
  cp build/rust/release/libpsiv_rust.a "build/rust/release/libpsiv_rust.$ext" "$d/"
  cp bindings/c/include/psiv_rust.h "$d/include/"
  cp -R bindings/wasm/licenses "$d/"
fi
