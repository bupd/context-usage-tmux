# context-usage-tmux

A tmux status-bar widget that shows your current Claude Code and Codex CLI
**5-hour rolling-window usage** as compact bars on the far right, with reset
countdowns and the date/time.

```
… [C~ ███▒▒ 62% ⏰2h14m] [G ██▒▒▒ 41% ⏰3h] 14:32 28-Apr
```

Same idea as the macOS menu-bar widgets (Usage4Claude, ClaudeBar, AIQuotaBar) —
but native to tmux, shell-only, no menu bar required.

## Install

One line in `~/.config/tmux/tmux.conf` after your other config:

```
run-shell "/path/to/context-usage-tmux/tmux/context-usage.tmux"
```

Reload tmux (`prefix + r` or `tmux source-file ~/.config/tmux/tmux.conf`).
The widget appears on the far right of the status bar within ~30s.

## Requirements

- tmux ≥ 3.2
- [`bun`](https://bun.sh/) (for `bunx` to invoke ccusage), `jq`, `flock`,
  `awk`, `date` (GNU coreutils)

## How it works

Data comes from [`ccusage`](https://github.com/ryoppippi/ccusage) for Claude
and the local Codex session JSONLs at `~/.codex/sessions/**/*.jsonl` for Codex
— both purely on-disk, no network calls to Anthropic/OpenAI from this project,
no credentials handled.

Two scripts:

- **Updater** (`bin/context-usage-update`) — long-running, single-instance via
  `flock`. Polls every 30s, writes JSON to `$XDG_RUNTIME_DIR/context-usage.json`.
- **Renderer** (`bin/context-usage-render`) — stateless, reads the cache, prints
  one line for `status-right`. ~60ms per render.

The `tmux/context-usage.tmux` entry point spawns the updater and prepends the
renderer to your existing `status-right`. It's idempotent — re-sourcing the
config doesn't double-up.

## Reading the bar

```
[C~ ███▒▒ 62% ⏰2h14m]
 │  │     │   │
 │  │     │   └── time until the 5h window resets
 │  │     └────── current usage percent
 │  └──────────── filled cells (each cell = 1/WIDTH of the window)
 └─────────────── tag: C = Claude, G = Codex/GPT; "~" = estimated
```

`~` on a tag means the percent is heuristic. Claude carries it because we
compute against ccusage's `--token-limit max` (max ever seen, not the official
plan limit). Codex doesn't — its session JSONLs include real OpenAI rate-limit
headers (`rate_limits.primary.used_percent`).

Color thresholds: green <50%, yellow 50–80%, red ≥80%.

If you see `[C —] [G —]`, the cache is missing or stale (>2 min old) — usually
means the updater died. Check `pgrep -fa context-usage-update`.

## Configuration

Environment variables (read by the updater / renderer):

| Var                            | Default | Effect                                       |
| ------------------------------ | ------- | -------------------------------------------- |
| `CONTEXT_USAGE_REFRESH_SECS`   | `30`    | How often the updater polls ccusage          |
| `CONTEXT_USAGE_BAR_WIDTH`      | `5`     | Bar width in cells                           |
| `CU_STALE_AFTER_SECS`          | `120`   | Cache age past which renderer shows fallback |
| `CODEX_HOME`                   | `~/.codex` | Where to look for Codex session JSONLs   |

## Verification

```sh
./test/data-layer.sh    # lib/* return contract-shaped JSON
./test/updater.sh       # --once writes cache; flock enforces single instance
./test/renderer.sh      # fresh / stale / missing cache all render correctly
```

Or run the bundled smoke runner:

```sh
./test/all.sh
```

## License

MIT — see [`LICENSE`](./LICENSE).
