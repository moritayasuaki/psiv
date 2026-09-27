#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ ! -f .local/wasm/generated/psiv_wasm_bg.wasm ]]; then
  echo "Run ./scripts/build.sh before packaging." >&2; exit 2
fi
mkdir -p .local/packages
cargo package --locked -p psiv --allow-dirty
version=$(python3 -c 'import json; print(json.load(open("bindings/wasm/package.json"))["version"])')
cp ".local/rust/package/psiv-$version.crate" .local/packages/
(cd .local/wasm && npm pack --ignore-scripts --cache ../npm-cache --pack-destination ../packages)
