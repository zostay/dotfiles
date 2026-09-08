---
kind: dotfiles
forge: github
tracker: github-issues
deploy.mode: manual
---

# nowthen profile — dotfiles

Sterling's personal dotfiles. `install.sh` symlinks files into `$HOME` (and
`$XDG_CONFIG_HOME`) and renders templated configs through a Perl `Text::Template`
layer whose output varies by OS and by "environment" — a work/personal context
recorded in `~/.dotfile-environment`. `CLAUDE.md` is the orientation for anyone
working here and is more detailed than this file.

**There is no test suite and no linter, and that is not an oversight.** Nothing
here has a build. A change is validated by re-running `./install.sh <environment>`
and inspecting the rendered output in the gitignored `.build/` tree and the
resulting symlinks in `$HOME`. A routine that wants a `test:` command will not
find one, and should not synthesize one.

**Deployment is manual and per-machine.** There is no CI — no `.github/workflows`
at all — so merging finishes nothing. Each machine gets the change by pulling and
re-running `./install.sh`. The exception is `bin/`, which is symlinked verbatim to
`~/bin`: editing a script there takes effect immediately on that machine, with no
install step.

**Two things need a person, and both are environmental rather than repository
problems.** Templates that reference secrets shell out to `op` (1Password CLI),
which requires Sterling's fingerprint and therefore his presence — if `op` fails
to authorize, the right move is to pause and ask rather than to work around it.
And `bin/rotate-music` authenticates through an unpacked Chrome extension against
a signed-in YouTube Music session; when that fails, record it and carry on.

Submodules are load-bearing (`vim/bundle/*`, `colorist`, `bin/Text-Template`,
`bin/YAML-Tiny`) — run `git submodule update --init --recursive` after pulling.
