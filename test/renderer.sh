#!/usr/bin/env bash
# Smoke test for bin/context-usage-render.
# Asserts fresh / stale / missing cache render correctly.

set -euo pipefail

cd "$(dirname "$0")/.."
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
export XDG_RUNTIME_DIR="$tmpdir"
source lib/common.sh

cache="$(cu_cache_path)"
fresh_now="$(cu_now_epoch)"
stale_now="$((fresh_now - 3600))"

write_cache() {
  local updated="$1"
  jq -n --argjson u "$updated" '{
    updated_at: $u,
    claude: {kind: "context", percent: 62, used_percent: 62, remaining_percent: 38, reset_epoch: 0, ok: true, estimated: false},
    codex:  {percent: 41, reset_epoch: ($u + 11000), ok: true, estimated: false}
  }' >"$cache"
}

# Fresh cache. Claude shows context left without a reset; Codex shows rate-limit left with reset.
write_cache "$fresh_now"
out="$(./bin/context-usage-render)"
if [[ $out != *'✳'*'ctx '*'38%] [#[fg=colour255]⏣'* || $out == *'✳'*'~'* || $out != *'⏣'*'59% ⏰'* ]]; then
  echo "FAIL  fresh render: $out"
  exit 1
fi
echo "ok    fresh: $out"

# Stale cache → fallback (with appended date/time).
write_cache "$stale_now"
out="$(./bin/context-usage-render)"
if [[ $out != "[✳ —] [⏣ —] "* ]]; then
  echo "FAIL  stale render: $out"
  exit 1
fi
echo "ok    stale: $out"

# Missing cache → fallback (with appended date/time).
rm -f "$cache"
out="$(./bin/context-usage-render)"
if [[ $out != "[✳ —] [⏣ —] "* ]]; then
  echo "FAIL  missing render: $out"
  exit 1
fi
echo "ok    missing: $out"
