# context-usage-tmux

A tmux status-bar widget that shows your current Claude Code and Codex CLI
**5-hour rolling-window usage** as compact bars on the far right, with reset
countdowns and the date/time.

```
… [C ███▒▒ 62% ⏰2h14m] [G ██▒▒▒ 41% ⏰3h] 14:32 28-Apr
```

Same idea as the macOS menu-bar widgets (Usage4Claude, ClaudeBar, AIQuotaBar) —
but native to tmux, shell-only, no menu bar required.

## Status

🚧 Early. See [`PLAN.md`](./PLAN.md) and the roadmap issues for what's coming.

## How it works

Data comes from [`ccusage`](https://github.com/ryoppippi/ccusage) and
[`@ccusage/codex`](https://www.npmjs.com/package/@ccusage/codex), both of which
read local JSONL files (`~/.claude/projects/`, `~/.codex/sessions/`) — no
credentials, no network calls to Anthropic/OpenAI from this project.

A small background updater polls ccusage every ~30s and writes a JSON cache;
tmux's `status-right` calls a stateless renderer that reads the cache.

## Requirements

- tmux ≥ 3.2
- `bun` (for `bunx` to invoke ccusage), `jq`, `flock`

## License

MIT — see [`LICENSE`](./LICENSE).
