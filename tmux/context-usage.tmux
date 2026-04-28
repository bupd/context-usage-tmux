#!/usr/bin/env bash
# Entry point sourced by tmux.conf:
#   run-shell "~/path/to/context-usage-tmux/tmux/context-usage.tmux"
#
# What it does:
#   1. Sets status-interval to 5 (renderer ticks every 5s).
#   2. Prepends our renderer to status-right (preserves any existing tail).
#   3. Spawns the updater in the background under flock — silent no-op if
#      another updater already holds the lock.
#
# Idempotent: sourcing the file twice does NOT double-prepend the renderer.

set -euo pipefail

CU_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CU_RENDERER="$CU_ROOT/bin/context-usage-render"
CU_UPDATER="$CU_ROOT/bin/context-usage-update"
CU_INVOCATION="#($CU_RENDERER)"
CU_MARKER="context-usage-render"   # used to detect prior install

cu_set_interval() {
  tmux set-option -g status-interval 5
  tmux set-option -g status-right-length 200
}

cu_install_status_right() {
  # The renderer is self-contained: it emits the bars *and* the date/time,
  # so we don't need to append any tmux date format. If the user already
  # has a status-right with things in it (e.g. git branch, session name),
  # we prepend the renderer; otherwise we just set it. Idempotent: if our
  # marker is already present, no-op.
  local current
  current="$(tmux show-option -gqv status-right || true)"
  if [[ $current == *"$CU_MARKER"* ]]; then
    return 0
  fi
  if [[ -n $current ]]; then
    tmux set-option -g status-right "$CU_INVOCATION $current"
  else
    tmux set-option -g status-right "$CU_INVOCATION"
  fi
}

cu_spawn_updater() {
  # nohup + & detaches from tmux; flock inside the updater enforces single-instance.
  nohup "$CU_UPDATER" >/dev/null 2>&1 &
  disown 2>/dev/null || true
}

cu_set_interval
cu_install_status_right
cu_spawn_updater
