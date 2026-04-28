# shellcheck shell=bash
# Codex CLI 5-hour usage via the codex app-server JSON-RPC.
#
# Codex 0.125+ stopped persisting the OpenAI rate-limit headers to
# ~/.codex/sessions/*.jsonl — they're now only available through the
# in-process `account/rateLimits/read` JSON-RPC call. We launch a one-shot
# `codex app-server` and ask it directly. Roundtrip is ~1.5s, well under
# the updater's 30s tick.
#
# Response shape (truncated):
#   {"id":2,"result":{"rateLimits":{
#     "primary":   {"usedPercent":0, "windowDurationMins":300, "resetsAt":<epoch>},
#     "secondary": {"usedPercent":0, "windowDurationMins":10080,"resetsAt":<epoch>},
#     "planType":"plus", ...
#   }}}
#
# Output shape (matches lib/claude.sh):
#   {"percent": <0-100>, "reset_epoch": <unix>, "ok": true|false, "estimated": false}
#
# estimated:false because this is the live, server-authoritative value.

cu_codex_home() {
  printf '%s' "${CODEX_HOME:-$HOME/.codex}"
}

cu_codex_bin() {
  printf '%s' "${CODEX_BIN:-codex}"
}

# Speak just enough JSON-RPC to grab the rate-limit snapshot, then close.
# stdout: raw JSON line of the result-bearing response (id=2). Empty on failure.
cu_codex_rpc_query() {
  local bin
  bin="$(cu_codex_bin)"
  command -v "$bin" >/dev/null 2>&1 || return 1

  {
    printf '{"jsonrpc":"2.0","method":"initialize","id":1,"params":{"clientInfo":{"name":"context-usage-tmux","title":"context-usage-tmux","version":"0.1.0"},"capabilities":{}}}\n'
    sleep 0.3
    printf '{"jsonrpc":"2.0","method":"account/rateLimits/read","id":2}\n'
    sleep 1.5
  } | timeout 10 "$bin" app-server 2>/dev/null \
    | jq -c 'select(.id == 2)' 2>/dev/null
}

cu_codex_fetch() {
  local resp
  resp="$(cu_codex_rpc_query)" || {
    cu_codex_error "codex app-server unavailable"
    return 0
  }
  if [[ -z $resp ]]; then
    cu_codex_error "no response from codex app-server"
    return 0
  fi

  local pct reset_epoch
  pct="$(jq -r '.result.rateLimits.primary.usedPercent // empty' <<<"$resp")"
  reset_epoch="$(jq -r '.result.rateLimits.primary.resetsAt // empty' <<<"$resp")"

  if [[ -z $pct ]]; then
    cu_codex_error "no rate-limit primary in response"
    return 0
  fi

  pct="$(awk -v p="$pct" 'BEGIN{if(p<0)p=0; if(p>100)p=100; printf "%.1f", p}')"
  reset_epoch="${reset_epoch:-0}"

  jq -nc --argjson p "$pct" --argjson r "$reset_epoch" \
    '{percent: $p, reset_epoch: $r, ok: true, estimated: false}'
}

cu_codex_error() {
  jq -nc --arg msg "$1" '{percent: 0, reset_epoch: 0, ok: false, estimated: false, error: $msg}'
}
