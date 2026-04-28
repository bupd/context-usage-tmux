#!/usr/bin/env bash
# Smoke test for lib/common.sh, lib/claude.sh, lib/codex.sh.
# Run from repo root: ./test/data-layer.sh

set -euo pipefail

cd "$(dirname "$0")/.."
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export XDG_RUNTIME_DIR="$tmpdir"
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

printf '%s\n' '{"model":{"display_name":"Opus"},"session_id":"test-session","context_window":{"used_percentage":25,"remaining_percentage":75,"context_window_size":200000,"total_input_tokens":50000,"total_output_tokens":1000,"current_usage":{"input_tokens":40000,"cache_creation_input_tokens":5000,"cache_read_input_tokens":5000,"output_tokens":1000}},"rate_limits":{"five_hour":{"used_percentage":12.5,"resets_at":1999999999}}}' \
  | ./bin/context-usage-claude-statusline >/dev/null

claude_json="$(cu_claude_fetch)"
check "claude.fetch" "$claude_json"
if ! jq -e '.ok == true and .kind == "context" and .percent == 25 and .remaining_percent == 75 and .reset_epoch == 0' <<<"$claude_json" >/dev/null; then
  echo "FAIL  claude.fetch context fields → $claude_json"
  fail=1
fi
check "codex.fetch"  "$(cu_codex_fetch)"

exit "$fail"
