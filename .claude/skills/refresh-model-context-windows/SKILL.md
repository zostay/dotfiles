---
name: refresh-model-context-windows
description: Refresh sessions/models.json (the Claude model context-window table that bin/sessions reads for its CONTEXT column) from Anthropic's public models documentation. Fetches the live docs with WebFetch — no API key required — regenerates the table deterministically, and commits only if the model data actually changed.
---

# Refresh model context windows

`bin/sessions` renders the CONTEXT column as `N/M`, where `M` is the model's
context window. It reads those windows from `sessions/models.json` (symlinked to
`$XDG_CONFIG_HOME/sessions/models.json` by `install.sh`). This skill refreshes
that table from Anthropic's **public** models page — it needs no API key, only a
`WebFetch`, so it runs fine inside any Claude Code session.

When a model isn't in the table, `bin/sessions` shows the raw token count in
lavender instead of inventing a denominator, so a stale table degrades gracefully
— but keeping it current is the point of running this weekly.

## Steps

1. **Confirm a clean tree** for `sessions/models.json`:
   `git status --porcelain sessions/models.json`. If it has uncommitted changes,
   stop and tell the user — don't fold their edits into an automated refresh.

2. **Fetch the live model data** with `WebFetch`:
   - URL: `https://platform.claude.com/docs/en/about-claude/models/overview.md`
   - Prompt: ask for every Claude model with its **Claude API alias**, its
     **context window / max input tokens**, and its **max output tokens**, across
     both the current and legacy tables.

3. **Build the new table** in the exact shape of the existing file:
   - Top-level keys: `_comment` (keep the current one verbatim), `updated`,
     `models`.
   - Under `models`, one entry per model, keyed by its **bare Claude API alias**
     (e.g. `claude-opus-4-8`, not `claude-opus-4-8-20251101`). For a model with no
     alias, use its API ID. `bin/sessions` strips `[1m]` / `-fast` / `-YYYYMMDD`
     suffixes before lookup, so keys must be the bare alias.
   - Each entry: `{ "context": <max input tokens>, "max_output": <max output tokens> }`
     as integers (`1M` → `1000000`, `200k` → `200000`, `128k` → `128000`).
   - **Sort the model keys alphabetically** and use 2-space indentation, so diffs
     stay minimal and reviewable.
   - Include every model the docs list, current and legacy. Don't drop a model
     just because it's deprecated — old sessions may still reference it.

4. **Diff against the current file, ignoring `updated`.** Compare only the
   `models` object (and `_comment`). If the model data is unchanged, **make no
   changes and do not commit** — report "model table already current" and stop.
   Do not bump `updated` when nothing else changed (it would churn a no-op commit).

5. **If the data changed**, set `updated` to today's date (YYYY-MM-DD), write the
   file, then sanity-check it:
   - `python3 -c "import json; json.load(open('sessions/models.json'))"` parses.
   - Spot-check that `claude-opus-4-8`, `claude-sonnet-4-6`, and `claude-haiku-4-5`
     are present with plausible windows (1M, 1M, 200k respectively as of this
     writing).

6. **Commit** just this file on the current branch:
   `git add sessions/models.json && git commit`. Use a message like
   `chore: refresh model context-window table` and summarize what changed (models
   added/removed, windows that moved). Don't push unless the user asks.

7. **Report** the net change: which models were added, removed, or had their
   window updated — or that the table was already current.

## Notes

- The only external dependency is the docs page's table format. If `WebFetch`
  comes back without a recognizable model table (page restructured, fetch failed),
  **stop and report it** — never write a partial or empty table over a good one.
- This is a read-of-public-docs operation. It must not require, look for, or use
  an `ANTHROPIC_API_KEY`.
