#!/usr/bin/env bash
# Run every smoke test in test/. Stops on first failure (set -e).
# Usage: ./test/all.sh

set -euo pipefail

cd "$(dirname "$0")/.."

tests=(
  test/data-layer.sh
  test/updater.sh
  test/renderer.sh
)

for t in "${tests[@]}"; do
  echo "==> $t"
  bash "$t"
  echo
done

echo "all green ✓"
