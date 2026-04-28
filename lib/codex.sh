# shellcheck shell=bash
# Codex CLI 5-hour usage via on-disk session JSONLs.
#
# Strategy: scan the most recent session files under $CODEX_HOME/sessions
# (default ~/.codex/sessions) for the latest event_msg of type token_count
# whose payload.rate_limits.primary is non-null. That payload carries the
# real, server-reported rate-limit data:
#   primary.used_percent  (0-100)
#   primary.window_minutes (300 for 5h)
#   primary.resets_at     (unix epoch)
#
# If resets_at is in the past, the rolling window has already cleared on the
# server, so report 0%. If no recent token_count event exists, report 0%.
#
# Output shape matches lib/claude.sh:
#   {"percent": <0-100>, "reset_epoch": <unix>, "ok": true|false, "estimated": false}
#
# estimated:false because this comes straight from OpenAI's rate-limit headers.

cu_codex_home() {
  printf '%s' "${CODEX_HOME:-$HOME/.codex}"
}

cu_codex_fetch() {
  local sess_dir
  sess_dir="$(cu_codex_home)/sessions"
  if [[ ! -d $sess_dir ]]; then
    cu_codex_error "no codex sessions dir"
    return 0
  fi

  # Newest 5 session files — enough to find a recent token_count without
  # scanning the entire history every tick.
  local files
  files="$(find "$sess_dir" -name '*.jsonl' -printf '%T@ %p\n' 2>/dev/null \
    | sort -rn | head -5 | cut -d' ' -f2-)"
  if [[ -z $files ]]; then
    jq -nc '{percent: 0, reset_epoch: 0, ok: true, estimated: false}'
    return 0
  fi

  # Find the most recent rate-limit reading by walking files newest-first
  # and grabbing the last token_count event with a non-null .primary.
  local latest=""
  while IFS= read -r f; do
    [[ -z $f ]] && continue
    local ev
    ev="$(jq -c 'select(.type=="event_msg" and .payload.type=="token_count" and .payload.rate_limits.primary != null) | .payload.rate_limits.primary' "$f" 2>/dev/null | tail -1)"
    if [[ -n $ev ]]; then
      latest="$ev"
      break
    fi
  done <<<"$files"

  if [[ -z $latest ]]; then
    jq -nc '{percent: 0, reset_epoch: 0, ok: true, estimated: false}'
    return 0
  fi

  local pct reset_epoch now
  pct="$(jq -r '.used_percent // 0' <<<"$latest")"
  reset_epoch="$(jq -r '.resets_at // 0' <<<"$latest")"
  now="$(cu_now_epoch)"

  if (( reset_epoch <= now )); then
    pct="0"
    reset_epoch="0"
  fi

  jq -nc --argjson p "$pct" --argjson r "$reset_epoch" \
    '{percent: $p, reset_epoch: $r, ok: true, estimated: false}'
}

cu_codex_error() {
  jq -nc --arg msg "$1" '{percent: 0, reset_epoch: 0, ok: false, estimated: false, error: $msg}'
}
