# shellcheck shell=bash
# Shared helpers for context-usage-tmux. Sourced by lib/* and bin/*.

cu_runtime_dir() {
  printf '%s' "${XDG_RUNTIME_DIR:-/tmp}"
}

cu_cache_path() {
  printf '%s/context-usage.json' "$(cu_runtime_dir)"
}

cu_lock_path() {
  printf '%s/context-usage.lock' "$(cu_runtime_dir)"
}

cu_now_epoch() {
  date +%s
}

# Atomic write: stdin → final path, via tmp-and-rename on the same filesystem.
cu_atomic_write() {
  local target="$1"
  local tmp
  tmp="$(mktemp "${target}.XXXXXX")" || return 1
  cat >"$tmp" || { rm -f "$tmp"; return 1; }
  mv -f "$tmp" "$target"
}

# ISO 8601 ("2026-04-28T16:00:00.000Z") → epoch seconds. Empty string on failure.
cu_iso_to_epoch() {
  local iso="$1"
  [[ -z $iso ]] && return 0
  date -u -d "$iso" +%s 2>/dev/null
}
