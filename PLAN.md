# context-usage-tmux — plan

## Context

Compact widget pinned to the **far right of the tmux status bar** that shows the current Claude Code 5-hour usage and the Codex CLI 5-hour usage as horizontal bars, plus reset countdowns and the date/time.

Why now: hitting the 5-hour rolling window on both Claude Code and Codex regularly, and want a passive, always-visible meter — same idea as the macOS menu-bar widgets (Usage4Claude, ClaudeBar, AIQuotaBar) but native to tmux. `ccusage` is the single source of truth — `ccusage` for Claude and `@ccusage/codex` for Codex, both reading local JSONL (no cookies, no network).

Target visual (one row, far right of status):

```
… [C ███▒▒ 62% ⏰2h14m] [G ██▒▒▒ 41% ⏰3h] 14:32 28-Apr
```

Color thresholds: green <50%, yellow 50–80%, red ≥80%. Uses tmux native `#[fg=...]` so colors work without external escapes.

## Step 1 — Roadmap as GitHub issues (FIRST, before any code)

Before writing any code, seed the repo with a roadmap of issues. The issues are **not** an imperative step-by-step todo list — each one is a short essay (2–4 paragraphs) that captures the *thinking* behind a slice of the work: what we're trying to achieve, open questions, trade-offs, where we'll likely land. Each issue after the first references the prior one ("Building on #1, …") so the thread reads like a design conversation that anyone could pick up and continue.

Concretely:

1. **Initialize the project structure.** Worktree at `~/code/OSS/bupd-context-usage-tmux/` (matches the harbor-style `{remote}-{description}` convention). Add `README.md`, `LICENSE` (MIT), `.editorconfig`, and **`PLAN.md`** (this file). Commits are conventional, signed, and small (<100 lines each) — no commits land on `main` directly; everything goes through PRs.
2. **Push and verify** the GitHub remote (`git@github.com:bupd/context-usage-tmux.git`).
3. **Open the roadmap issues** via `gh issue create`:

   - **Issue A — "What this widget is, and what it isn't"**
     Frames the project: a tmux-native, bar-on-the-far-right meter for Claude Code and Codex CLI 5-hour windows. Why we're not building another macOS menu-bar app, and why we're not relying on browser cookies or private APIs — this exists *because* `ccusage` already nails the data layer and we just need to surface it in tmux. Personal setup but written so anyone can drop it into their tmux config.

   - **Issue B — "Why ccusage, and the Codex caveat" (refs A)**
     Building on A: walks through the ccusage family (`ccusage`, `@ccusage/codex`, `@ccusage/opencode`) and why we picked it (no creds, local JSONL, multi-provider, actively maintained). The awkward bit: Claude has `ccusage blocks --active --json` today, but `@ccusage/codex` only ships `daily`/`monthly`/`session` so far — no `blocks` yet. Two paths (parse `~/.codex/sessions/*.jsonl` ourselves for a 5h sum, or wrap `session --json --since "5h ago"`) and which we'd prefer until upstream lands `blocks`.

   - **Issue C — "Cache-and-render split, and how we keep the bar fast" (refs B)**
     Building on B: a background updater that writes JSON to `$XDG_RUNTIME_DIR/context-usage.json` every ~30s, and a stateless renderer that the tmux `status-right` calls every 5s. The renderer must never block the bar (no `bunx`/network in the hot path); the updater must be resilient to ccusage being slow or missing. Stale-cache fallback (`[C —] [G —]`) and lockfile (`flock` on `$XDG_RUNTIME_DIR/context-usage.lock`) so multiple tmux servers don't spawn duplicate updaters.

   - **Issue D — "Visual language — bars, colors, glyphs, width" (refs C)**
     Building on C: the actual look. Bars + reset countdown + date. Glyph set (`█`/`▒`), bar width (5 cells default, configurable), color thresholds (green/yellow/red at 50/80%), and a `~` suffix on Codex (`[G~ ...]`) until upstream `blocks` lands. Aligns with the existing `cmux.conf` palette so the widget doesn't visually clash with the pane-border styling.

   - **Issue E — "tmux glue, install ergonomics, and the one-line user contract" (refs D)**
     Building on D: how this gets wired in. Goal: one `run-shell` line in `tmux.conf`, TPM-style. Ships a `tmux/context-usage.tmux` entry point that spawns the updater under `flock` and sets `status-right`/`status-interval`. Trade-off of being a TPM-installable plugin vs. a plain `run-shell` snippet — lands on the snippet.

   - **Issue F — "Verification, edge cases, and what happens when ccusage is missing" (refs E)**
     Building on E: closes the loop on testing. Smoke-test path (cache populates, renderer prints, bar renders inside tmux, stale-cache fallback works, single updater per machine, Codex fallback when bun/ccusage isn't there). Longer-tail cases — laptop sleep/wake, no Claude usage yet today, Codex auth expired.

Each issue closes with a "Likely landing" paragraph stating the direction we'd take if no one disagrees.

## Step 2 onwards — Implementation

Once the issues are open, implementation proceeds against them. A/B → no code; C → updater + cache; D → renderer; E → tmux glue; F → tests.

### Files to create

- `PLAN.md` — this document.
- `README.md` — install steps, env vars (`CODEX_5H_TOKEN_BUDGET`, `CONTEXT_USAGE_BAR_WIDTH`, `CONTEXT_USAGE_REFRESH_SECS`), troubleshooting.
- `bin/context-usage-update` — updater loop (bash). `--once` flag for tests.
- `bin/context-usage-render` — renderer (bash + jq). Stateless, fast (<5ms), reads cache only.
- `lib/claude.sh` — wraps `bunx ccusage blocks --active --json`, normalizes to `{percent, reset_epoch, ok}`.
- `lib/codex.sh` — wraps `@ccusage/codex` with raw-JSONL fallback (`~/.codex/sessions/**/*.jsonl`, 5h sum vs `CODEX_5H_TOKEN_BUDGET`). Marks `estimated: true` until upstream `blocks` ships.
- `lib/bar.sh` — pure-shell bar renderer (percent → `███▒▒` + tmux `#[fg=...]` color).
- `tmux/context-usage.tmux` — entry point: spawns updater via `flock`, sets `status-right` and `status-interval 5`.
- `LICENSE` (MIT), `.editorconfig`.

### Cache JSON shape (project contract — referenced from Issue C)

```json
{
  "updated_at": 1745851234,
  "claude": { "percent": 62, "reset_epoch": 1745859274, "ok": true },
  "codex":  { "percent": 41, "reset_epoch": 1745862834, "ok": true, "estimated": true }
}
```

### tmux.conf hookup (one line for the user)

Append to `~/.config/tmux/tmux.conf`, after the existing `run '~/.tmux/plugins/tpm/tpm'` line:

```
run-shell "~/code/OSS/bupd-context-usage-tmux/tmux/context-usage.tmux"
```

The `.tmux` script sets `status-interval 5`, sets `status-right` to call the renderer, and starts the updater under `flock`.

## Reuse / existing utilities

- **`ccusage` and `@ccusage/codex`** — single source of truth. Run via `bunx`; no global install needed.
- **`jq`, `flock`, `sqlite3`** — already on the system.
- **`cmux-notify.sh` color palette** (colour39/220/196/46) — reuse so the widget visually matches the existing tmux setup.

## Files to modify (outside the project)

- `~/.config/tmux/tmux.conf` — append the one `run-shell` line above.

## Verification

End-to-end smoke test (Issue F):

1. **Cache populates:** `bin/context-usage-update --once && jq . $XDG_RUNTIME_DIR/context-usage.json` — both `claude` and `codex` have `percent`, `reset_epoch`, `ok: true`.
2. **Renderer prints:** `bin/context-usage-render` — one line, two bars, percentages, countdowns, no error markers.
3. **Renders inside tmux:** reload tmux config (`prefix + r`); right side of status shows the widget. Run a Claude prompt, watch `C` move within ~30s.
4. **Stale-cache fallback:** `rm $XDG_RUNTIME_DIR/context-usage.json` → bar shows `[C —] [G —]` instead of breaking.
5. **Single updater:** kill and restart tmux server; `pgrep -fa context-usage-update | wc -l` → 1.
6. **Codex fallback:** temporarily move `~/.bun/bin/bun` aside; renderer should show `[G~ ?]` without breaking Claude.
