# shellcheck shell=bash
# Claude Code live context usage via its official statusLine payload.
# bin/context-usage-claude-statusline writes the latest payload-derived state
# to $XDG_RUNTIME_DIR/context-usage-claude.json; the updater reads it here.

cu_claude_stale_secs() {
  printf '%s' "${CONTEXT_USAGE_CLAUDE_STALE_SECS:-180}"
}

cu_claude_fetch() {
  local cache
  cache="$(cu_claude_cache_path)"
  if [[ ! -s $cache ]]; then
    cu_claude_error "no Claude statusLine cache"
    return 0
  fi

  local now updated stale age
  now="$(cu_now_epoch)"
  updated="$(jq -r '.updated_at // 0' "$cache" 2>/dev/null || printf '0')"
  [[ $updated =~ ^[0-9]+$ ]] || updated=0
  stale="$(cu_claude_stale_secs)"
  age=$((now - updated))
  if (( updated == 0 || age > stale )); then
    cu_claude_error "stale Claude statusLine cache"
    return 0
  fi

  local state
  state="$(jq -c '
    def pct:
      (try (if . == null then 0 else tonumber end) catch 0)
      | if . < 0 then 0 elif . > 100 then 100 else . end;

    (.percent | pct) as $used
    | {
        kind: "context",
        percent: $used,
        used_percent: ((.used_percent // $used) | pct),
        remaining_percent: ((.remaining_percent // (100 - $used)) | pct),
        reset_epoch: 0,
        ok: true,
        estimated: false,
        context_window_size: (.context_window_size // 0),
        current_usage: (.current_usage // null),
        total_input_tokens: (.total_input_tokens // 0),
        total_output_tokens: (.total_output_tokens // 0),
        model: (.model // null),
        session_id: (.session_id // null),
        rate_limit: (.rate_limit // null)
      }
  ' "$cache" 2>/dev/null)" || {
    cu_claude_error "invalid Claude statusLine cache"
    return 0
  }

  if [[ -z $state || $state == "null" ]]; then
    cu_claude_error "invalid Claude statusLine cache"
    return 0
  fi

  printf '%s\n' "$state"
}

cu_claude_error() {
  jq -nc --arg msg "$1" '{kind: "context", percent: 0, used_percent: 0, remaining_percent: 0, reset_epoch: 0, ok: false, estimated: false, error: $msg}'
}
