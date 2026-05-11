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

## Repository layout notes

- `bin/` is symlinked verbatim to `~/bin`. Anything dropped here becomes a user command.
- `vim/bundle/`, `colorist/`, `bin/Text-Template`, `bin/YAML-Tiny` are git submodules — run `git submodule update --init --recursive` after pulling.
- `.build/` is gitignored; it holds rendered templates and is the staging area `tmpl-link-file` reads from.
- `~/.zshrc.local` is sourced by `zsh/rc/98-zsh.local` for machine-local overrides and secrets (e.g. `LPASS_USERNAME`); it is not checked in.
