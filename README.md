# Installation

Clone this repo and initialize it:

    git clone git@github.com:zostay/dotfiles.git
    cd dotfiles
    git submodule init
    git submodule update

Add this to `~/.zshrc.local`

    export LPASS_USERNAME="username"

Load the into the current environment:

    source ~/.zshrc.local

Run:

    ./install.sh <environment>

## macOS

Install [Homebrew](https://github.com/Homebrew/brew/blob/master/docs/Installation.md#installation).

Install FiraCode font from here:

* <https://github.com/tonsky/FiraCode>

# Install My Packages

Install local packages:

    ./packages.sh

# Mail

Add this to crontab if this is a mail checking machine:

    */15 * * * * ~/bin/label-mail > /dev/null

# `workon`: per-project tmux layouts

`workon` starts (or jumps to) a tmux session for a project, with a 3-pane
layout tuned for coding alongside a Claude Code agent and the
[recon](https://github.com/gavraz/recon) dashboard.

## Layout

    +---------------------------+---------------------------+
    |  shell                    |  claude                   |
    |  (supervised zsh)         |  (supervised)             |
    |                           |                           |
    +---------------------------+                           |
    |  recon  (~20% tall)       |                           |
    +---------------------------+---------------------------+
    |  [proj-1] [proj-2]* [proj-3]                 12:34    |  <- tmux status
    +-------------------------------------------------------+

- **Left top — shell**: an interactive `zsh` wrapped by `work-supervisor`.
  When the shell exits, you get an in-pane menu instead of a closed pane.
- **Right — claude**: `claude` wrapped by the same supervisor. `/exit` drops
  to the same menu rather than killing the pane.
- **Left bottom — recon**: wrapped by `recon-loop`, which restarts recon
  forever (and prints a friendly hint if `recon` isn't on PATH).
- **Status line**: every live tmux session is a clickable "tab" (rendered
  by `bin/work-status`); the current one is highlighted.

## Basic usage

    workon <project>           # session "<project>"
    workon <project> <path>    # session "<project>", working dir <path>

Project names resolve in this order:

1. `$HOME/projects/<name>`
2. `$GOPATH/src/github.com/<name>`
3. `$PWD/<name>`

So `workon 0/dotfiles` opens `~/projects/0/dotfiles` as session `dotfiles`
(the `0/` prefix is stripped). Periods in the resolved name are replaced
with hyphens because tmux doesn't allow them in session names.

If you run `workon` again for a session that already exists, it just
switches to it — no setup happens twice.

## Multiple work threads on one project (`-w`)

    workon -w feature <project>

`-w <name>` does two things:

- Names the tmux session `<project>-<name>` instead of `<project>`.
- Creates (or attaches to) a git worktree at
  `<parent>/<project>-worktrees/<name>` on branch `<name>`. The branch is
  created from `HEAD` if it doesn't exist.

The default work is `prime`, which is *not* a worktree — it just uses the
project directory directly.

    workon dotfiles                 # session: dotfiles      dir: ~/projects/0/dotfiles
    workon -w spike dotfiles        # session: dotfiles-spike dir: ~/projects/0/dotfiles-worktrees/spike

## Editor mode (`-e`)

    workon -e <project>

Adds a second tmux window named `edit` running `vim` against a saved
`.session.vim` (see `bin/add-editor`). Skip it if you're working
entirely in Claude.

## Per-session environment (`.workon.env`)

You can inject environment variables into a tmux session — and every pane it
spawns — by placing a `.workon.env` file anywhere from `$HOME` down to the
project directory.

`workon` calls `bin/workon-env` before creating the session. It walks from
`$HOME` to the session directory (shallowest first), reading `.workon.env`
then `.workon.local.env` in each directory. Later files win, so a
project-level file overrides a home-level one, and `.workon.local.env`
overrides `.workon.env` in the same directory.

The variables are passed to `tmux new-session -e` and become part of the
session environment; every pane (shell, claude, recon, editor) inherits them.

**File format** (dotenv-style, never sourced — no arbitrary code runs):

```sh
# Comments and blank lines are ignored.
export OPTIONAL=ok          # leading "export " is stripped

MY_TOKEN=abc123             # bare value
BASE_URL="https://example.com"   # double-quoted: $VAR expansion allowed
LITERAL='no $expansion here'     # single-quoted: literal
DERIVED=$BASE_URL/api       # references earlier vars or the real environment

unset SOME_INHERITED_VAR    # strips the var from the session entirely
```

- `NAME` must match `[A-Za-z_][A-Za-z0-9_]*`.
- `$VAR` / `${VAR}` in bare or double-quoted values resolves against
  variables accumulated so far in this parse, then falls back to the real
  environment. Undefined → empty.
- Command substitution (`$(...)`, backticks) is **never** evaluated; it
  passes through as literal text.
- Bare values may have a trailing ` # comment`; quote the value to keep a
  literal `#`.

Commit `.workon.env` for settings the whole team shares; add `.workon.local.env`
to `.gitignore` for secrets or machine-specific overrides.

## In-pane menu

When the wrapped command in the shell or claude pane exits, the supervisor
prints:

      [c] claude    (default)
      [o] codex
      [s] shell
      [x] close pane (kills the whole session)

Press one key. Enter accepts the default (`claude`). Choosing `[x]` from
either pane tears down the *entire* session — shell, claude, and recon —
not just that pane.

## Key bindings

Prefix is `C-j` (unchanged from before).

| Binding                | Action                                           |
|------------------------|--------------------------------------------------|
| `Alt-Left` / `Alt-Right` | Cycle to previous / next session (no prefix)   |
| `prefix g`             | Open `recon` in a popup (no session switch)      |
| `prefix i`             | Jump to the next agent waiting for input         |
| `prefix s`             | Interactive session picker                       |
| `prefix W`             | Prompt for a `workon` argument and run it        |
| `prefix X`             | Confirm + kill the current session               |
| `MouseDown1Status`     | Click a session label in the status line to jump |

`Alt-Left` / `Alt-Right` shadow zsh's `backward-word` / `forward-word`. Use
`Alt-b` / `Alt-f` instead for word jumping at the command line.

The tmux server cleans itself up automatically when the last session
closes (`session-closed` hook), so the next `workon` cold-starts.

## Dependencies

- `tmux >= 3.1` (for percentage splits and `display-popup`)
- [`recon`](https://github.com/gavraz/recon) — `./install.sh` installs it
  via `cargo install --git ...` if it's missing. If installation fails
  (e.g. no `cargo`), the bottom-left pane prints a "not installed" hint
  and retries every 30 s.
- `codex` on `$PATH` if you want the `[o]` menu option to work
- `claude` on `$PATH` (already configured by `zsh/rc/85-claude`)

## Files behind it

| Script                | Role                                                  |
|-----------------------|-------------------------------------------------------|
| `bin/workon`          | Entry point; resolves project + worktree, builds session |
| `bin/add-claude`      | Creates the 3-pane layout in window 0                 |
| `bin/add-editor`      | Adds the `edit` window when `-e` is passed            |
| `bin/work-supervisor` | Relaunch loop + menu around shell/claude/codex        |
| `bin/recon-loop`      | Restart-recon-forever wrapper                         |
| `bin/work-status`     | Emits the clickable session list for the status line  |
| `bin/work-switch`     | Resolves a status-line click index to a session name  |
| `bin/work-worktree`   | Idempotent `git worktree add` helper                  |
| `bin/workon-env`      | Resolves the `.workon.env` cascade for a session dir  |
