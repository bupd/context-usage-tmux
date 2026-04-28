# context-usage-tmux

A tmux status-bar widget that shows your current Claude Code and Codex CLI
**5-hour rolling-window usage** as compact bars on the far right, with reset
countdowns and the date/time.

```
… [✱~ ██▒▒▒ 38% ⏰2h14m] [⏣ ███▒▒ 59% ⏰3h] 14:32 28-Apr
```

`✱` is Claude (orange), `⏣` is OpenAI/Codex (white) — single-glyph stand-ins
for each vendor's logo, drawn in their brand color. The percent shown is
how much of the 5h window is **remaining** — full bar = full tank.

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
- `codex` CLI (≥ 0.125) on `$PATH` — used to query Codex's rate-limit RPC

## How it works

Data sources, both local — no credentials handled by this project:

- **Claude**: [`ccusage`](https://github.com/ryoppippi/ccusage), invoked via
  `bunx`. Reads `~/.claude/projects/**/*.jsonl`.
- **Codex**: a one-shot `codex app-server` subprocess speaking the
  `account/rateLimits/read` JSON-RPC. Returns the same primary/secondary
  rate-limit windows the Codex TUI shows in its status bar.

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
[✱~ ██▒▒▒ 38% ⏰2h14m]
 │  │     │   │
 │  │     │   └── time until the 5h window resets
 │  │     └────── percent of the window *remaining* (38 = 38% left)
 │  └──────────── filled cells (each cell = 1/WIDTH of the remaining window)
 └─────────────── tag: ✱ = Claude (orange), ⏣ = Codex/OpenAI (white); "~" = estimated
```

`~` on a tag means the percent is heuristic. Claude carries it because we
report ccusage's `tokenLimitStatus.percentUsed`, which is computed against
`--token-limit max` (max ever seen, not the official plan limit). Codex
doesn't — it pulls live values from the codex app-server's
`account/rateLimits/read` RPC.

Color thresholds (on percent **remaining**): green >50%, yellow 20–50%,
red ≤20% (almost out).

If you see `[✱ —] [⏣ —]`, the cache is missing or stale (>2 min old) —
usually means the updater died. Check `pgrep -fa context-usage-update`.

If Codex shows `[⏣ ?]`, the `codex` CLI isn't on `$PATH` or its
`account/rateLimits/read` RPC didn't respond — install codex ≥ 0.125 or
override the binary location with `CODEX_BIN=/path/to/codex`.

If your terminal font lacks `✱`/`⏣`/`█`/`▒`, set `CU_PLAIN=1` in the
environment for an ASCII-safe fallback (`C`/`G`/`#`/`-`).

## Configuration

Environment variables (read by the updater / renderer):

| Var                            | Default | Effect                                       |
| ------------------------------ | ------- | -------------------------------------------- |
| `CONTEXT_USAGE_REFRESH_SECS`   | `30`    | How often the updater polls ccusage          |
| `CONTEXT_USAGE_BAR_WIDTH`      | `5`     | Bar width in cells                           |
| `CU_STALE_AFTER_SECS`          | `120`   | Cache age past which renderer shows fallback |
| `CODEX_BIN`                    | `codex` | Codex CLI binary used for the rate-limit RPC    |
| `CODEX_HOME`                   | `~/.codex` | Reserved for future on-disk fallbacks         |

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
