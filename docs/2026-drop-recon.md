# Dropping `recon`: native Claude session monitoring

`recon` (the Rust `~/.cargo/bin/recon`, v0.6.1) appears to be going stale. `bin/sessions`
shells out to `recon json` every refresh to list Claude Code sessions. This plan replaces
that with a direct reader — symmetric with the Codex reader already in `bin/sessions` — so the
dependency can be dropped.

## How shallow the dependency is

Across `bin/`, the only *functional* use of recon is `fetch_claude()` in `bin/sessions`
(`subprocess.run(["recon", "json"])`). Everything else is stale:

- `bin/recon-loop` — orphan; nothing launches it. `bin/add-claude` launches `sessions-loop`.
- `bin/add-claude`, `bin/workon`, `bin/work-supervisor` — the word "recon" only in comments.

recon's `launch` / `next` / `resume` / `park` subcommands are unused: `workon` launches
`claude` directly, and `sessions` implements the `n` next-input jump itself. So dropping recon
is: rewrite one Python function, delete one dead script, scrub comments.

## How recon derives its data (from binary strings, v0.6.1)

recon does exactly what `fetch_codex()` already does, against different sources:

- **Panes:** `tmux list-panes -a -F '#{pane_pid}|||#{session_name}|||#{pane_current_command}|||#{pane_current_path}|||...'`
- **Process match:** `pgrep -P` / `ps -o args=` to find the real `claude` process. Needed because
  in our layout `claude` runs under `work-supervisor`, so `pane_current_command` is the wrapper —
  the same problem solved for Codex with a ppid walk.
- **Tokens/model/branch:** parses `~/.claude/projects/<mangled-cwd>/<id>.jsonl`
  (`message.model`, `message.usage.{input_tokens,cache_read_input_tokens,cache_creation_input_tokens,output_tokens}`);
  `git -C <cwd> rev-parse --abbrev-ref`.
- **Status:** `tmux capture-pane -t <pane> -p` + JSONL last-entry type.

Verified: last assistant entry's `input + cache_read + cache_creation` reproduces recon's
"45k / 200k" context display exactly. cwd→dir mangling is `/`→`-` and `.`→`-`.

## Field-by-field replacement

| `fetch_claude` field | Replacement source |
|---|---|
| `cwd`, `project_name`, `short_dir` | matched claude pane's `pane_current_path` |
| `tmux_session` | matched pane's `session_name` |
| `branch` | `git -C <cwd> rev-parse --abbrev-ref HEAD` |
| `model_display` | last non-sidechain assistant entry `message.model` |
| `context_str` / `ratio` | sum of last assistant `usage.*` ÷ context window |
| `ts` | last JSONL entry `timestamp` |
| `status` / `waiting` | hybrid: JSONL last-type + pane-capture (see below) |

Pane → JSONL: mangle `pane_current_path`, glob `~/.claude/projects/<mangled>/`, take newest
`*.jsonl`, and verify its `cwd` field equals the pane path (guards against mangling collisions).

## Status detection (the only real decision)

Everything else is mechanical; "idle / running / waiting on me" is the work. Chosen approach is
**hybrid**, structured so the status function is swappable:

- Coarse Idle-vs-Running from the JSONL last conversational entry type (last `assistant` = turn
  ended = Idle; trailing `user`/tool-result with no later assistant = Running).
- A single `capture-pane -p` upgrades to the red **Input** state when a permission prompt /
  attention box is on screen.

Alternative for later: Claude `Stop` / `Notification` / `UserPromptSubmit` hooks writing
`~/.claude/session-status/<id>.json`. Exact and scrape-free, but these dotfiles don't currently
manage a Claude `settings.json`, so it adds install surface + stale-file cleanup. Deferred.

## Implementation steps

1. `live_claude_panes()` — mirror `live_codex_panes()`, matching the `claude` binary (exclude the
   `Claude.app` desktop helper and the wrapper), walking ppid up to a `pane_pid`.
2. `jsonl_for_cwd(path)` — mangle cwd → project dir → newest `*.jsonl`, verify `cwd`.
3. `parse_claude_jsonl(file)` — single reverse/tail pass for last assistant model+usage, last
   timestamp, last conversational entry type; skip `isSidechain`.
4. `claude_status(pane, last_type)` — hybrid logic above.
5. Rewrite `fetch_claude()` to assemble records from 1–4. **Return schema unchanged**, so all
   rendering / sorting / `n` / switch logic is untouched.
6. Update `load_sessions()` warning text; share the one `ps` / `list-panes` scan between Claude
   and Codex fetchers.
7. Delete `bin/recon-loop`; scrub "recon" from comments in `add-claude`, `workon`,
   `work-supervisor`, and the `sessions` docstring.
8. Update `CLAUDE.md`'s `bin/sessions` paragraph to describe the JSONL+tmux approach.

## Risks / edge cases

- **Context window** is model-dependent (200k vs 1M). Pick from model when known, default 200k —
  same fuzziness recon has.
- **Worktrees:** `pane_current_path` already reports the worktree dir, so mangling just works.
- **Sidechains** (`isSidechain:true`): skip when choosing last model / activity so a background
  agent's tokens don't masquerade as the main thread.
- **Perf:** one `ps` + one `list-panes` per refresh (shared with Codex) + one tail-read per
  session. Cheaper than spawning `recon` every 5s.
- **Status accuracy** is the only place we may diverge from recon; the pane-capture red-state path
  is the piece to test against a live permission prompt.

## Effort

~Half a day, ~120 lines of Python closely mirroring `fetch_codex()`. No new dependencies, no
install-pipeline changes. The schema boundary at `fetch_claude()` means the ~500 lines of
rendering/input code never change. Genuinely novel work is just `claude_status()`.

## Follow-up: process-centric via Claude's session registry

The first cut was *transcript-centric* — find the newest `*.jsonl` under the cwd-mangled project
dir. That had three real bugs, exposed by two `reading-list` sessions showing as zero:

1. **Wrong config dir.** Per-client sessions run with `CLAUDE_CONFIG_DIR` (e.g.
   `~/projects/bambee/.claude`); their registry *and* transcripts live there, not under `~/.claude`.
   Mangling `~/.claude/projects` found nothing for them — and worse, for cwds that also had a
   default-config transcript it silently read the *wrong* one (wrong model/tokens).
2. **Brand-new sessions** have no transcript yet, so they were invisible (recon showed them "New").
3. **Two sessions in one cwd** both mapped to the same newest transcript; the dedup dropped one.

Fix: key on the **process**, not the transcript. Claude maintains an authoritative registry at
`<config_dir>/sessions/<pid>.json` — `{ pid, sessionId, cwd, status, updatedAt, ... }`. So:

- Enumerate live `claude` pids (one row each → New sessions and same-cwd siblings both appear).
- Read each pid's `CLAUDE_CONFIG_DIR` from its environment (`ps eww`); default `~/.claude`.
- `read_session_registry(cfg, pid)` → `sessionId` + `cwd` + `status`.
- `transcript_for(cfg, cwd, sessionId)` is now an **exact** path (no mtime guessing); a
  `newest_transcript()` cwd-match remains only as a fallback when the registry is missing.
- Status comes from the registry (`busy`→Running, `idle`→Idle, `shell`→Idle), with the
  `capture-pane` upgrade kept only for the red "Input"/permission state, and "New" when a pid has
  no transcript. The per-client config dir (not a cwd prefix) drives the bambee SESSION color.
