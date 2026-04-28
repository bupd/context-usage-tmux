# shellcheck shell=bash
# Pure-shell bar renderer. Maps a 0-100 percent to a colored block-glyph
# string sized for the tmux status bar.
#
#   cu_bar_render PERCENT [WIDTH]
#
# Output format:
#   #[fg=COLOR]██▒▒▒#[default]
#
# Colors track the cmux.conf palette so the widget visually matches the
# user's existing pane-border styling:
#   <50%   colour46  green
#   50-80% colour220 yellow
#   >=80%  colour196 red

CU_BAR_FILLED='█'
CU_BAR_EMPTY='▒'

cu_bar_color() {
  local pct="$1"
  if   awk "BEGIN{exit !($pct >= 80)}"; then printf 'colour196'
  elif awk "BEGIN{exit !($pct >= 50)}"; then printf 'colour220'
  else                                       printf 'colour46'
  fi
}

cu_bar_render() {
  local pct="${1:-0}"
  local width="${2:-${CONTEXT_USAGE_BAR_WIDTH:-5}}"
  local filled
  # Round to the nearest cell. Clamp to [0, width].
  filled="$(awk -v p="$pct" -v w="$width" 'BEGIN{
    n = int((p/100.0)*w + 0.5);
    if (n < 0) n = 0;
    if (n > w) n = w;
    print n
  }')"
  local empty=$((width - filled))
  local bar=""
  local i
  for ((i=0; i<filled; i++)); do bar+="$CU_BAR_FILLED"; done
  for ((i=0; i<empty;  i++)); do bar+="$CU_BAR_EMPTY"; done
  printf '#[fg=%s]%s#[default]' "$(cu_bar_color "$pct")" "$bar"
}

# Format an epoch reset time as "Xh", "XhYm", or "Ym" relative to now.
# Returns "?" if reset_epoch is 0 or in the past.
cu_bar_countdown() {
  local reset="$1" now
  now="$(cu_now_epoch)"
  if [[ -z $reset || $reset -eq 0 || $reset -le $now ]]; then
    printf '?'
    return
  fi
  local secs=$((reset - now))
  local h=$((secs / 3600))
  local m=$(((secs % 3600) / 60))
  if   (( h > 0 && m > 0 )); then printf '%dh%dm' "$h" "$m"
  elif (( h > 0 ));          then printf '%dh' "$h"
  else                            printf '%dm' "$m"
  fi
}
