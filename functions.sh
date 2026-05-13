function __mkdir {
    if [[ ! -d $1 ]]; then mkdir -p $1; fi
}

function backup-file {
    __mkdir "$HOME/.dotfiles.bak"
    if [[ -h "$1" ]]; then # clobber symlinks
        rm -rf "$1"
    elif [[ -e "$1" ]]; then # backup anything else
        mv "$1" "$HOME/.dotfiles.bak/${1:t}"
    fi
}

function link-file {
  __mkdir "${2:h}"
  backup-file "$2"
  ln -s "$PWD/$1" "$2"
}

function copy-file {
  __mkdir "${2:h}"
  backup-file "$2"
  cp "$PWD/$1" "$2"
}

function tmpl-file {
  __mkdir ".build"
  [[ "$1" =~ "/" ]] && __mkdir ".build/$(dirname "$1")"
  template-dotfile $DOTFILE_ENV "$1" ".build/$1"
}

function tmpl-link-file {
  tmpl-file "$1"
  [[ -f ".build/$1" ]] && link-file ".build/$1" "$2"
}

function setup-completion {
    local base=$(basename "$1")
    echo -n "Setting completion for $base ..."
    local rc=0
    if [[ -x "$GOPATH/bin/$base" ]]; then
        build_completion "$GOPATH/bin/$base"
        rc=$?
    elif hash "$1" 2> /dev/null; then
        build_completion "$1"
        rc=$?
    fi
    if (( rc == 0 )); then
        echo "done."
    else
        echo "failed (exit $rc)."
        if [[ -e ./skipped-completions.txt ]] && ! grep -qxF "$base" ./skipped-completions.txt; then
            echo "$base" >> ./skipped-completions.txt
            echo "  -> added '$base' to skipped-completions.txt"
        fi
    fi
}

function build_completion {
    local cmd="$1"
    local base=$(basename "$cmd")
    local -a runner=()
    if command -v gtimeout >/dev/null 2>&1; then
        runner=(gtimeout 5)
    fi
    local COMPLETION
    COMPLETION="$("${runner[@]}" "$cmd" completion zsh 2> /dev/null)"
    local rc=$?
    if (( rc == 0 )); then
        echo "$COMPLETION" > "./zsh/comp/_$base"
    fi
    return $rc
}

# install-cargo-crate BIN_NAME GIT_URL
#
# Ensure a Rust binary crate is installed. No-op if BIN_NAME is already
# on PATH; otherwise runs `cargo install --git GIT_URL`. Warns and
# continues if cargo isn't available.
function install-cargo-crate {
    local bin_name="$1"
    local git_url="$2"
    if command -v "$bin_name" >/dev/null 2>&1; then
        echo "$bin_name already installed at $(command -v $bin_name)"
        return 0
    fi
    if ! command -v cargo >/dev/null 2>&1; then
        echo "[warn] cargo not found; skipping $bin_name install from $git_url" >&2
        return 1
    fi
    echo "Installing $bin_name from $git_url ..."
    # Use the system git CLI for fetching so url.insteadOf rewrites and the
    # user's ssh-agent / credential helper behave the same as a normal
    # `git clone`. Without this, cargo's libgit2 backend fails on hosts
    # that rewrite https://github.com to ssh://git@github.com.
    CARGO_NET_GIT_FETCH_WITH_CLI=true cargo install --git "$git_url" || {
        echo "[warn] failed to install $bin_name from $git_url" >&2
        return 1
    }
}

# vim: ft=zsh
