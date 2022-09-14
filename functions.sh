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
    base=$(basename "$1")
    echo -n "Setting completion for $base ..."
    if [[ -x "$GOPATH/bin/$base" ]]; then
        build_completion "$GOPATH/bin/$base"
    elif hash "$1" 2> /dev/null; then
        build_completion "$1"
    fi
    echo "done."
}

function build_completion {
    base=$(basename "$1")
    COMPLETION="$("$1" completion zsh 2> /dev/null)"
    if [[ $? -eq 0 ]]; then
        echo "$COMPLETION" > "./zsh/comp/_$base"
    fi
}

# vim: ft=zsh
