#!/usr/bin/env bash
# Smoke test for bin/context-usage-update.
# - --once writes a valid cache file
# - second concurrent instance silently exits (single-instance flock)

set -euo pipefail

cd "$(dirname "$0")/.."
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export XDG_RUNTIME_DIR="$tmpdir"
source lib/common.sh

cache="$(cu_cache_path)"
lock="$(cu_lock_path)"
rm -f "$cache" "$lock"

printf '%s\n' '{"model":{"display_name":"Opus"},"session_id":"test-session","context_window":{"used_percentage":20,"remaining_percentage":80,"context_window_size":200000}}' \
  | ./bin/context-usage-claude-statusline >/dev/null

# 1) --once writes the cache.
./bin/context-usage-update --once
if ! jq -e '.updated_at and .claude.kind == "context" and .claude.remaining_percent == 80 and .codex.ok != null' "$cache" >/dev/null; then
  echo "FAIL  cache shape invalid → $(cat "$cache")"
  exit 1
fi
echo "ok    --once produced valid cache"

# 2) Single-instance flock: launch loop, then a second loop, expect only one process.
CONTEXT_USAGE_REFRESH_SECS=10 ./bin/context-usage-update >/dev/null 2>&1 &
A=$!
sleep 0.3
./bin/context-usage-update >/dev/null 2>&1 &
B=$!
sleep 0.3

if kill -0 "$B" 2>/dev/null; then
  echo "FAIL  second instance still running (PID=$B)"
  kill "$A" "$B" 2>/dev/null || true
  exit 1
fi
echo "ok    second instance exited (flock held by first)"

kill "$A" 2>/dev/null || true
wait 2>/dev/null || true
rm -f "$cache" "$lock"
