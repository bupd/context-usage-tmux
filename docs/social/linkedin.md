# LinkedIn — launch post draft

> This is a draft. Copy/paste into LinkedIn and post manually.
> Don't auto-publish.

---

**Shipped: `context-usage-tmux` — Claude Code context & Codex CLI usage in your tmux status bar**

If you live in tmux and use Claude Code or OpenAI's Codex CLI, you've
probably watched Claude context fill up or hit a Codex 5-hour limit and lost
a chunk of flow figuring out what happened.

The macOS world has a few menu-bar widgets for this (Usage4Claude,
ClaudeBar, AIQuotaBar). None of them help when your terminal is
fullscreen. So I built a tmux-native version: one `run-shell` line,
two compact bars on the far right of your status bar, percent remaining,
Codex reset countdown, and date/time.

```
[✳ ctx ██▒▒▒ 38%] [⏣ ███▒▒ 59% ⏰3h] 14:32 28-Apr
```

`✳` is Claude (orange), `⏣` is OpenAI/Codex (white). Bars go yellow
under 50% remaining and red under 20%. No daemon, no creds, no
network calls — purely local data sources you already have.

**A few things I learned shipping this:**

→ Claude's live context percentage is exposed through Claude Code's official
`statusLine` payload, not the historical JSONL logs. A tiny bridge script
caches that payload locally so tmux can show context remaining without
guessing.

→ Codex 0.125 moved its rate-limit state out of the `~/.codex/sessions`
JSONLs and into in-memory only. JSONL-based scrapers like
`@ccusage/codex` silently report zero against this layout. The fix is
to spawn `codex app-server` (the JSON-RPC subprocess the official TUI
uses) and call `account/rateLimits/read`. ~1.5s roundtrip — fine for a
30-second background poll, not fine for the tmux hot path.

→ The architecture that fell out: a Claude statusLine bridge, a background
updater holding a `flock`, polling sources every 30s, writing JSON to
`$XDG_RUNTIME_DIR/context-usage.json`. A stateless renderer that tmux calls
every 5s, reads the file, prints in ~60ms, exits. The pieces never share
memory. Reloading tmux is idempotent.

**Install:**

```
run-shell "~/code/context-usage-tmux/tmux/context-usage.tmux"
```

That's it. Reload tmux, widget appears within 30s.

MIT-licensed. PRs welcome — adding a vendor is one short shell file.
Code: https://github.com/bupd/context-usage-tmux

#tmux #developertools #claudecode #openai #cli #opensource
