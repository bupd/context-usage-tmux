#!/usr/bin/env bash
# Smoke test for bin/context-usage-render.
# Asserts fresh / stale / missing cache render correctly.

set -euo pipefail

cd "$(dirname "$0")/.."
source lib/common.sh

cache="$(cu_cache_path)"
fresh_now="$(cu_now_epoch)"
stale_now="$((fresh_now - 3600))"

write_cache() {
  local updated="$1"
  jq -n --argjson u "$updated" '{
    updated_at: $u,
    claude: {percent: 62, reset_epoch: ($u + 8000), ok: true, estimated: true},
    codex:  {percent: 41, reset_epoch: ($u + 11000), ok: true, estimated: false}
  }' >"$cache"
}

# Fresh cache.
write_cache "$fresh_now"
out="$(./bin/context-usage-render)"
if [[ $out != *'[C~ '*'62% '* || $out != *'[G '*'41% '* ]]; then
  echo "FAIL  fresh render: $out"
  exit 1
fi
echo "ok    fresh: $out"

# Stale cache → fallback.
write_cache "$stale_now"
out="$(./bin/context-usage-render)"
if [[ $out != "[C —] [G —]" ]]; then
  echo "FAIL  stale render: $out"
  exit 1
fi
echo "ok    stale: $out"

# Missing cache → fallback.
rm -f "$cache"
out="$(./bin/context-usage-render)"
if [[ $out != "[C —] [G —]" ]]; then
  echo "FAIL  missing render: $out"
  exit 1
fi
echo "ok    missing: $out"
