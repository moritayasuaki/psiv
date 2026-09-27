#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p releases/packages
python3 scripts/collect_rust_notices.py
cargo package --locked -p psiv --allow-dirty
cp build/rust/package/psiv-0.5.0-experimental.crate releases/packages/
(cd bindings/wasm && npm pack --ignore-scripts --cache ../../build/npm-cache --pack-destination ../../releases/packages)
