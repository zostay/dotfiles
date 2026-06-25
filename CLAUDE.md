# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

Sterling's personal dotfiles. `install.sh` symlinks files into `$HOME` (and `$XDG_CONFIG_HOME`) and renders templated configs through a Perl-based templating layer that varies output by OS and "environment" (work/personal context).

## Common commands

```sh
# First-time setup (also re-runs idempotently to update symlinks)
git submodule update --init --recursive
./install.sh <environment>          # records env to ~/.dotfile-environment
./install.sh                        # re-uses recorded env
./install.sh -c <environment>       # skip rebuilding shell completions

# Build/push the Docker images used for testing template rendering
./build-docker.sh
```

Valid environment names live as keys under `environments:` in `dotfiles.yml` (currently `home`, `fullstack`, `solo.io`, `speakeasy`, `ziprecruiter`). Passing an unknown name still writes it to `~/.dotfile-environment`, but `bin/check-dotfiles-environment` will then fail on the next run because the merged config will be empty.

There is no test suite or linter. Validate changes by re-running `./install.sh` and inspecting `.build/` for templated output and the resulting symlinks in `$HOME`.

## How the install pipeline works

`install.sh` sources `functions.sh`, which exposes four primitives used throughout:

- `link-file SRC DST` — back up any existing `DST` to `~/.dotfiles.bak/`, then symlink `$PWD/SRC` → `DST`.
- `copy-file SRC DST` — same, but copies instead of symlinking.
- `tmpl-file NAME` — runs `bin/template-dotfile $DOTFILE_ENV NAME .build/NAME`, rendering `NAME.tmpl` into the gitignored `.build/` tree.
- `tmpl-link-file NAME DST` — `tmpl-file` followed by `link-file .build/NAME DST`.

Adding a new dotfile means choosing the right primitive in `install.sh`. Adding a templated dotfile additionally requires creating `NAME.tmpl` and (usually) adding a per-environment entry under `environments:` in `dotfiles.yml`.

## Templating layer

`bin/template-dotfile` is a Perl script using `Text::Template` with **`[% ... %]` delimiters** (not the usual `{{ }}` — Mustache/Jinja syntax will not work). It pulls vendored libs from submodules (`bin/Text-Template`, `bin/YAML-Tiny`) and the in-repo `bin/lib/Zostay.pm`.

Config resolution (`Zostay::dotfiles_config`):

1. Reads `~/.dotfiles.yml` if present, else `./dotfiles.yml`.
2. Merges four layers (later wins): `oses.*`, `oses.<os>`, `environments.*`, `environments.<env>`.
3. The resulting hash for the requested file is exposed as template variables. `$config->{__SKIP__}` truthy → the file is silently skipped.
4. Any leaf value shaped `{ __SECRET__: NAME }` is replaced by running `op read op://Robots/NAME/password` (1Password CLI). `op` must be installed and signed in for templates that reference secrets.

When editing `dotfiles.yml`, remember the merge is shallow per-file: each top-level filename maps to a flat hash of fields.

## ZSH configuration

`zshrc` sources every file in `~/.zsh/rc/` in lexical order, so the numeric prefix on each filename in `zsh/rc/` is meaningful:

- `00-path` seeds `$PATH` with system dirs.
- `10-` to `30-` set aliases, options, completion.
- `85-<tool>` files configure individual toolchains (go, rust, python, ruby, node, claude, …). These are the right place to add per-tool PATH/env setup.
- `97-<env>` files apply environment-specific shell settings, gated on the contents of `~/.dotfile-environment`.
- `99-finalize` prepends `$HOME/bin` and `$HOME/local/bin`, dedupes the path, exports `PATH`, and unsets the path helpers.

**Always use the path helpers**, never raw `PATH=…` edits or ad-hoc string checks. Source them once at the top of an rc file:

```zsh
. "$HOME/.zsh/functions/paths"
__prepend_paths "$HOME/.cargo/bin"   # or __append_paths, __remove_path
```

These wrappers (`zsh/functions/paths`) operate on zsh's `path` array, only add directories that exist, and de-dup. They are unset by `99-finalize`, so any file numbered ≥99 cannot use them.

## The `workon` development environment

`bin/workon <project>` creates (or switches to) a per-project tmux session with a 3-pane coding layout. Because `bin/` is symlinked to `~/bin`, editing any of these scripts updates the live command immediately — no `./install.sh` re-run is needed. The user-facing docs live in the README's "`workon`: per-project tmux layouts" section; this is the orientation for agents working *on* the scripts.

**Layout** (`bin/add-claude` builds it in window 0): shell (`zsh`) left-top, `claude` on the right at full height, and `bin/sessions` (a Python TUI monitor) in a ~20% bottom-left pane kept alive by `bin/sessions-loop`. The shell and claude panes are wrapped by `bin/work-supervisor`.

**`bin/work-supervisor`** keeps a pane alive after its command exits and shows an in-pane menu (`[c]laude / [o]codex / [p] copilot / [s]hell / [x] close workon session`). The menu is data-driven: `CMD_KEY`/`CMD_LABEL`/`CMD_BIN` is the registry of known launchers (add a row + a `run_choice` case to teach it a new one), and the `MENU` array picks which to show and in what order — overridable per-machine/project via the `WORK_SUPERVISOR_MENU` env var (space-separated tokens, set through the `workon-env` cascade). A launcher whose `CMD_BIN` isn't on `$PATH` renders dimmed `(not installed)` and is left out of `keymap`, so its key is unselectable — that's how the menu reflects, e.g., codex on one laptop and copilot on another. Structural gotcha: the menu prompt runs in an **inner** `while` loop, and that matters. A `continue` in the inner loop redraws the menu; a `continue` at the *outer* loop re-runs `run_choice "$next"` and silently relaunches the last command. So unknown keys must `continue` the inner loop and valid choices `break` out of it — never collapse the two loops. `[x]` runs `exec tmux kill-session` to tear down the whole session; with `detach-on-destroy off` the client then lands in another session. Typeahead is drained (`read -t 0`) before each menu read so stray bytes (e.g. leftover mouse-tracking output from `sessions`) aren't read as a choice.

**Session creation** (`bin/workon`): resolves the project dir (`~/projects/<name>`, then `$GOPATH/src/github.com/<name>`, then `$PWD/<name>`), pins the new *detached* session to the client's real dimensions so percentage splits resolve, seeds the session environment from the `.workon.env` cascade (`bin/workon-env`, `$HOME` → session dir, `.workon.local.env` wins), then `switch-client`s to it. Re-running `workon` for an existing session just switches — setup never runs twice. **Leave the switch/resume path alone** when changing menu behavior; the two are independent.

**Worktrees** (`workon -w <work>`): names the session `<project>-<work>` and uses a worktree at `<project>-worktrees/<work>` (`bin/work-worktree`). The supervisor launches `claude -w <work>` so Claude's `WorktreeCreate` hook (`bin/work-worktree-hook`) files the session under the worktree instead of chdir'ing back to the main checkout. The default `prime` work is *not* a worktree.

**`bin/sessions`** merges Claude and Codex sessions into one list, discovering both the same way: a single tmux-pane + process-table scan (`scan_panes`), then a ppid walk (`owning_pane`) from each agent's real process — `claude`, or the Rust `codex` binary — up to the tmux pane that owns it (the agents run under wrappers, so `pane_current_command` is not the agent). Claude is **process-centric**: one row per live `claude` pid. Each pid's `CLAUDE_CONFIG_DIR` (read from its env; per-client setups like bambee point it off `~/.claude`) locates that session's state — Claude's own registry `<config_dir>/sessions/<pid>.json` gives the `sessionId`, `cwd`, and live status (busy/idle/shell), and the `sessionId` names the exact transcript `<config_dir>/projects/<mangled-cwd>/<sessionId>.jsonl` (model, token usage → context display, last activity). **Don't go back to cwd-mangling alone to find the transcript** — two sessions can share a cwd, and a bambee session's transcript is not under `~/.claude`; both bugs come back. Status is the registry value, with a `capture-pane` upgrade to the red "Input" state on a permission prompt, and "New" when a pid has no transcript yet. Codex state comes from its SQLite store. There is no longer any `recon` dependency. The CONTEXT column's `N/M` shows used tokens over the model's context window; `M` comes from a dotfiles-managed table (`sessions/models.json`, symlinked to `$XDG_CONFIG_HOME/sessions/models.json`, re-read live on mtime change) — **not** inferred from the model id or token count. A model missing from the table renders just `N` in lavender (`ctx_window` returns `None`); the table is refreshed from Anthropic's public model docs by the `refresh-model-context-windows` skill, run during `maintenance-weekly`. It enables raw mode + mouse tracking (`\033[?1003h\033[?1006h`) and restores the terminal (termios + `\033[?1003l\033[?1006l\033[?25h`) in a `finally` block on exit — if that restore is ever bypassed, leftover escape bytes leak into the adjacent pane's stdin. `j`/`k`/arrows navigate, `Enter`/click switches sessions, `n` jumps to the next input-waiting agent.

**tmux glue** (`tmux.conf.tmpl`): `status-left` renders clickable session "tabs" via `bin/work-status` (a click → `bin/work-switch` by 0-based index, since tmux caps range identifiers at 15 chars); `detach-on-destroy off` switches a client elsewhere when its session is destroyed; the `session-closed` hook kills the server once the last session closes so the next `workon` cold-starts. These three are intentional and load-bearing — don't "simplify" them away.

## Repository layout notes

- `bin/` is symlinked verbatim to `~/bin`. Anything dropped here becomes a user command.
- `vim/bundle/`, `colorist/`, `bin/Text-Template`, `bin/YAML-Tiny` are git submodules — run `git submodule update --init --recursive` after pulling.
- `.build/` is gitignored; it holds rendered templates and is the staging area `tmpl-link-file` reads from.
- `~/.zshrc.local` is sourced by `zsh/rc/98-zsh.local` for machine-local overrides and secrets (e.g. `LPASS_USERNAME`); it is not checked in.
