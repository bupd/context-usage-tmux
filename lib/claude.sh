# shellcheck shell=bash
# Claude Code 5-hour usage via ccusage. Outputs a single JSON object on stdout:
#   {"percent": <0-100>, "reset_epoch": <unix>, "ok": true|false, "estimated": true|false}
#
# Why "estimated": ccusage derives the token limit from "max ever seen"
# (--token-limit max), which is a heuristic, not the official plan limit.
# The percent is therefore an approximation. Switch off when Claude Code
# exposes rate-limit headers to disk.

cu_claude_fetch() {
  local raw
  raw="$(timeout 30 bunx ccusage@latest blocks --active --token-limit max --json 2>/dev/null)" || {
    cu_claude_error "ccusage failed"
    return 0
  }

  local block
  block="$(jq -c '.blocks[] | select(.isActive == true)' <<<"$raw" 2>/dev/null)"
  if [[ -z $block || $block == "null" ]]; then
    # No active block — user hasn't used Claude in the current 5h window.
    jq -nc '{percent: 0, reset_epoch: 0, ok: true, estimated: true}'
    return 0
  fi

  # ccusage's tokenLimitStatus.percentUsed already reflects projected usage
  # (totalTokens + projected burst), which is what the live dashboard shows.
  # Use it directly so our bar matches `ccusage blocks --live`.
  local raw_pct end_iso
  raw_pct="$(jq -r '.tokenLimitStatus.percentUsed // 0' <<<"$block")"
  end_iso="$(jq -r '.endTime // ""' <<<"$block")"

  local reset_epoch percent
  reset_epoch="$(cu_iso_to_epoch "$end_iso")"
  reset_epoch="${reset_epoch:-0}"
  percent="$(awk -v p="$raw_pct" 'BEGIN{if(p<0)p=0; if(p>100)p=100; printf "%.1f", p}')"

  jq -nc --argjson p "$percent" --argjson r "$reset_epoch" \
    '{percent: $p, reset_epoch: $r, ok: true, estimated: true}'
}

cu_claude_error() {
  jq -nc --arg msg "$1" '{percent: 0, reset_epoch: 0, ok: false, estimated: true, error: $msg}'
}
