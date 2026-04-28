# Twitter / X — launch post drafts

> These are drafts. Copy/paste the one you like into your client and post
> manually. Don't auto-publish — public posts are irreversible.

---

## Option A — short, hooky

just shipped `context-usage-tmux`

claude code context + codex cli 5-hour usage on the far right of your tmux status bar. one `run-shell` line, two bars, color-coded as you run out.

`[✳ ctx ██▒▒▒ 38%] [⏣ ███▒▒ 59% ⏰3h]`

mit. https://github.com/bupd/context-usage-tmux

---

## Option B — problem-first

ever hit a claude code or codex limit mid-flow and lost 10 mins figuring out *whether* you'd actually hit it?

made a tmux widget that just shows you. two bars, brand colors, reset countdowns. no menu bar, no daemon, no creds.

https://github.com/bupd/context-usage-tmux

---

## Option C — technical

fun bug fixing this:

claude's live context percentage is in the official statusLine stdin payload, not the historical jsonl logs. cache that payload locally and tmux can show context left without guessing.

then codex 0.125 moved rate-limits in-memory. you have to spawn `codex app-server` and JSON-RPC `account/rateLimits/read` to read them. fun.

both fixed in `context-usage-tmux`: https://github.com/bupd/context-usage-tmux

---

## Reply-to-self thread (optional, after Option B)

**Reply 1:**
how it works: claude statusLine writes context to a sidecar cache. a background updater polls that + codex app-server every 30s and writes JSON to `$XDG_RUNTIME_DIR/context-usage.json`. a stateless renderer prints in ~60ms. tmux never blocks on a slow shell.

**Reply 2:**
install:
```
run-shell "~/code/context-usage-tmux/tmux/context-usage.tmux"
```
that's it. reload tmux, widget appears in ~30s.
