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

**Session creation** (`bin/workon`): resolves the project dir (`~/projects/<name>`, then `$GOPATH/src/github.com/<name>`, then `$PWD/<name>`, then a one-level `~/projects/*/<name>` glob so a bare project name filed under an org dir resolves — that's the name `sessions` shows in PROJECT), pins the new *detached* session to the client's real dimensions so percentage splits resolve, seeds the session environment from the `.workon.env` cascade (`bin/workon-env`, `$HOME` → session dir, `.workon.local.env` wins), then `switch-client`s to it. Re-running `workon` for an existing session just switches — setup never runs twice.

**The resume check runs before any filesystem work**, and must stay that way. `SESSION_NAME` depends only on `basename $NAME` and `$WORK_NAME`, so an existing session can always be re-entered without resolving the project dir or calling `work-worktree`. When the dir resolution came first (it used to), `workon -w <work> <project>` written with a *different but equivalent* spelling than the original invocation — bare vs org-qualified — fell through to `DIR="$HOME"` and died in `work-worktree` ("not a git working tree") instead of switching to the session sitting right there. If the session is gone but the worktree isn't, `work-worktree` reuses the existing directory as-is (no `git worktree add`, no branch reset), so that path reopens the work too. **Leave the switch/resume path alone** when changing menu behavior; the two are independent.

**Worktrees** (`workon -w <work>`): names the session `<project>-<work>` and uses a worktree at `<project>-worktrees/<work>` (`bin/work-worktree`), which becomes the cwd of every pane. The default `prime` work is *not* a worktree. **Never launch the claude pane with `claude -w`** — that makes Claude create and own a *second* worktree under `<main-checkout>/.claude/worktrees/<work>`, so the shell pane and the claude pane sit in different directories and the client's `.workon.env`/direnv setup rooted at the real worktree never loads. `-w` was originally added (commit `aca5af6`, along with a `WorktreeCreate` hook that was never actually registered in any `settings.json`) to stop interactive claude chdir'ing to the main checkout via `--git-common-dir`; that bug is gone as of Claude Code 2.1.220, and bare `claude` adopts the pane's worktree cwd. If it ever returns, the fix is a `WorktreeCreate` hook delegating to `bin/work-worktree` — recoverable from git history — and it must be registered in **every** `CLAUDE_CONFIG_DIR` (per-client dirs like bambee's don't read `~/.claude/settings.json`).

**`bin/sessions`** merges Claude and Codex sessions into one list, discovering both the same way: a single tmux-pane + process-table scan (`scan_panes`), then a ppid walk (`owning_pane`) from each agent's real process — `claude`, or the Rust `codex` binary — up to the tmux pane that owns it (the agents run under wrappers, so `pane_current_command` is not the agent). Claude is **process-centric**: one row per live `claude` pid. Each pid's `CLAUDE_CONFIG_DIR` (read from its env; per-client setups like bambee point it off `~/.claude`) locates that session's state — Claude's own registry `<config_dir>/sessions/<pid>.json` gives the `sessionId`, `cwd`, and live status (busy/idle/shell), and the `sessionId` names the exact transcript `<config_dir>/projects/<mangled-cwd>/<sessionId>.jsonl` (model, token usage → context display, last activity). **Don't go back to cwd-mangling alone to find the transcript** — two sessions can share a cwd, and a bambee session's transcript is not under `~/.claude`; both bugs come back. Status is the registry value, with a `capture-pane` upgrade to the red "Input" state on a permission prompt, and "New" when a pid has no transcript yet. **Background work — subagents, dynamic workflows, backgrounded shells — does not move the registry off "idle"** (the sole exception is `local_bash`, reported as "shell"), so such a session would otherwise read Idle. It is recovered from the pane's **footer region** — everything below the composer's bottom rule, which `footer_region()` finds by scanning up for the last full-width rule — matched against `BG_LABELS`, Claude Code 2.1.x's full indicator vocabulary, each mapping to a teal STATUS word (Agents/Workflow/Shell/Tasks/…). Three things are load-bearing: (1) **the mode line is not reliably the last row** — a running workflow pins a live progress row *under* it, which is why the region is taken whole rather than indexed from the end; (2) **a workflow the turn is awaiting never appears in the mode line at all** (it is the turn, not a backgrounded task), so its pinned `N/M agents done` row is the only evidence there is; (3) **match the footer only, never the scrollback, and keep the leading-count anchor** — the permanent "← for agents" hint shares the mode line and would otherwise read as a running agent forever. A registry carrying `statusUpdatedAt` is from a version that maintains `status`, so its `busy`/`shell` is trusted as a last resort (a clipped footer); without that field the ≤2.1.169 never-clears-busy bug applies and only pane evidence counts. LAST ACTIVE still means *main-thread* activity and is deliberately not advanced by background work — instead `LIVE_STATUSES` keeps the session name bold while work is in flight, so a session parked on a two-hour workflow can't fade out. Codex state comes from its SQLite store. There is no longer any `recon` dependency. The CONTEXT column's `N/M` shows used tokens over the model's context window; `M` comes from a dotfiles-managed table (`sessions/models.json`, symlinked to `$XDG_CONFIG_HOME/sessions/models.json`, re-read live on mtime change) — **not** inferred from the model id or token count. A model missing from the table renders just `N` in lavender (`ctx_window` returns `None`); the table is refreshed from Anthropic's public model docs by the `refresh-model-context-windows` skill, run during `maintenance-weekly`. It enables raw mode + mouse tracking (`\033[?1003h\033[?1006h`) and restores the terminal (termios + `\033[?1003l\033[?1006l\033[?25h`) in a `finally` block on exit — if that restore is ever bypassed, leftover escape bytes leak into the adjacent pane's stdin. `j`/`k`/arrows navigate, `Enter`/click switches sessions, `n` jumps to the next input-waiting agent.

**tmux glue** (`tmux.conf.tmpl`): `status-left` renders clickable session "tabs" via `bin/work-status` (a click → `bin/work-switch` by 0-based index, since tmux caps range identifiers at 15 chars); `detach-on-destroy off` switches a client elsewhere when its session is destroyed; the `session-closed` hook kills the server once the last session closes so the next `workon` cold-starts. These three are intentional and load-bearing — don't "simplify" them away.

## YouTube Music rotation auth

`bin/rotate-music` authenticates itself on every run — there is no separate login step. The shared logic lives in `bin/rotate_music_auth.py`, imported by both `rotate-music` and `rotate-music-login`.

**The credential is single-use.** `acquire()` wakes the extension, waits for the native host to write `auth_file`, reads it, and **unlinks it before returning** — so it is on disk for well under a second and is gone before the first API call. `YTMusic` accepts a dict (`auth: str | JsonDict | None`), so nothing downstream needs the file, and nothing in ytmusicapi writes back to it for browser auth (only OAuth's `store_token` and `setup_browser` write, and neither is on this path). **Don't reintroduce a cached auth file** — re-authenticating costs about a second and keeps a password-and-2FA-bypassing credential off the disk.

The one exception is `rotate-music-login --ask`, the manual fallback: it writes a persistent file because a human paste cannot be automated, and `acquire()` falls back to that file and deliberately leaves it in place. `rotate-music-login` is otherwise setup-and-diagnostics only (`--install`, or bare to check the pipeline end to end and discard the result).

**Why the auth file only really needs `cookie`.** ytmusicapi recomputes `authorization` from the SAPISID cookie before *every* request (`ytmusic.py`, `headers` property). The stored `authorization` is a *type marker* only — `auth/auth_parse.py` sniffs it for the substring `SAPISIDHASH` to classify the file as browser auth. So the extension writes a placeholder there on purpose; it is not a stubbed-out TODO. `X-Goog-Visitor-Id` is fetched automatically when absent. The cookie must contain `__Secure-3PAPISID` (`helpers.py`, `sapisid_from_cookie`).

**Why this needs a browser extension, and not something lighter.** 12 of the 16 cookies in a jar that actually authenticates — `__Secure-1PSID`, `__Secure-3PSID`, `LOGIN_INFO`, `SSID`, … — are **HttpOnly**. That rules out, permanently:

- `document.cookie` / any content script, including Claude in Chrome's `javascript_tool`. It sees 4 of the 16, and not one of them is a session cookie. SAPISIDHASH is only a CSRF-style proof the caller can read SAPISID; it is *not* a substitute for the session cookie, so a jar scraped from JS authenticates as nobody.
- A devtools/CDP session against the running browser. Chrome 136+ ignores `--remote-debugging-port` unless paired with a non-default `--user-data-dir`, specifically to stop cookie extraction — and a fresh `--user-data-dir` is a logged-out profile.

`chrome.cookies` is the only interface that returns HttpOnly cookies, hence `chrome/rotate-music-auth/` (MV3, `cookies` permission, ID pinned to `bnadenigkfcpiclddcamdoeikmmkkjbp` by the manifest `key`). If someone "simplifies" this to `document.cookie`, it will appear to work — a file gets written, `__Secure-3PAPISID` is present — and then every API call 401s. `describe()` guards against exactly that by requiring an HttpOnly marker in the jar.

**`host_permissions` must stay `https://*.youtube.com/*`.** Narrowing it to `music.youtube.com` looks tighter and silently breaks auth: Chrome filters `cookies.getAll` per-cookie against each cookie's *own* domain, so a `.youtube.com` cookie is checked as `https://youtube.com/`, which only the wildcard (which covers the apex) matches. Nearly the whole jar is domain-scoped, so the result would be a plausible-looking file that fails to authenticate.

**The auth file is a live credential**, equivalent to the account's YouTube session with no password and no 2FA, kept in plaintext at mode 600 — a weaker tier than Chrome's own Keychain-encrypted, TCC-protected cookie store. That is why the extension writes **only on demand**: an earlier version kept it permanently fresh on a 15-minute alarm plus every `cookies.onChanged`, which maximised the exposure window for no benefit, and made every organic YTM page load a web-reachable trigger for a native-host spawn. The only automatic write is a tab carrying the exact `?rotate-music-auth=wake` query parameter, which `rotate-music-login` opens and the extension then closes. **Don't add a periodic refresh back.**

**Handoff.** The extension can't write files, so it pipes headers to `bin/rotate-music-auth-host` (native messaging), which writes the auth file atomically at mode 600. Chrome spawns native hosts with a bare environment — no pyenv, so no PyYAML — which is why the host is **stdlib-only** and regexes `auth_file:` out of the YAML instead of parsing it. It must keep running on system Python (3.9).

`rotate-music-login` (default) validates the file and, if missing/stale/`--force`, wakes the extension by opening a background YTM tab (`tabs.onUpdated` fires the refresh) and waits for the mtime to move. `--ask` keeps the old paste-a-cURL flow as a fallback. `--install` registers the native host into every Chrome/Canary/Chromium profile found and is re-run by `install.sh`; loading the unpacked extension stays a one-time manual step.

## Repository layout notes

- `bin/` is symlinked verbatim to `~/bin`. Anything dropped here becomes a user command.
- `vim/bundle/`, `colorist/`, `bin/Text-Template`, `bin/YAML-Tiny` are git submodules — run `git submodule update --init --recursive` after pulling.
- `.build/` is gitignored; it holds rendered templates and is the staging area `tmpl-link-file` reads from.
- `~/.zshrc.local` is sourced by `zsh/rc/98-zsh.local` for machine-local overrides and secrets (e.g. `LPASS_USERNAME`); it is not checked in.
