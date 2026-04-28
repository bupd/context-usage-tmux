#!/usr/bin/env bash
# Smoke test for lib/common.sh, lib/claude.sh, lib/codex.sh.
# Run from repo root: ./test/data-layer.sh

set -euo pipefail

cd "$(dirname "$0")/.."
source lib/common.sh
source lib/claude.sh
source lib/codex.sh

fail=0
check() {
  local label="$1" json="$2"
  if ! jq -e '.percent != null and .reset_epoch != null and .ok != null' <<<"$json" >/dev/null; then
    echo "FAIL  $label: missing required fields → $json"
    fail=1
  else
    echo "ok    $label → $json"
  fi
}

check "common.cu_runtime_dir" "{\"percent\":0,\"reset_epoch\":0,\"ok\":true,\"path\":\"$(cu_runtime_dir)\"}"
check "claude.fetch" "$(cu_claude_fetch)"
check "codex.fetch"  "$(cu_codex_fetch)"

exit "$fail"
