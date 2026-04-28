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

  local total limit end_iso
  total="$(jq -r '.totalTokens // 0' <<<"$block")"
  limit="$(jq -r '.tokenLimitStatus.limit // 0' <<<"$block")"
  end_iso="$(jq -r '.endTime // ""' <<<"$block")"

  local reset_epoch percent
  reset_epoch="$(cu_iso_to_epoch "$end_iso")"
  reset_epoch="${reset_epoch:-0}"

  if [[ $limit -gt 0 ]]; then
    percent="$(awk -v t="$total" -v l="$limit" 'BEGIN{p=(t*100.0)/l; if(p>100)p=100; printf "%.1f", p}')"
  else
    percent="0"
  fi

  jq -nc --argjson p "$percent" --argjson r "$reset_epoch" \
    '{percent: $p, reset_epoch: $r, ok: true, estimated: true}'
}

cu_claude_error() {
  jq -nc --arg msg "$1" '{percent: 0, reset_epoch: 0, ok: false, estimated: true, error: $msg}'
}
