#!/bin/zsh

# Thanks, Frew, for the inspiration!

PATH="$PWD/bin:$PATH"
SKIP_COMPLETIONS=0
while getopts "c" opt; do
    case $opt in
        c)
            SKIP_COMPLETIONS=1
            ;;
    esac
done
shift $OPTIND-1

. ./functions.sh

echo "Initializing git submodules."
git submodule update --init --recursive

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:=$HOME/.config}

if [[ -n $* ]]; then
    DOTFILE_ENV=$1;
    echo $DOTFILE_ENV >! ~/.dotfile-environment
    shift;
elif [[ -e ~/.dotfile-environment ]]; then
    DOTFILE_ENV=$(cat ~/.dotfile-environment)
else
    echo You must specify the name of this environment on the first run. >&2
    exit 1
fi

#if hash lpass 2> /dev/null && [[ -z "$LPASS_USERNAME" ]]; then
#    echo You must put the following line into .zshrc.local: >&2
#    echo >&2
#    echo export LPASS_USERNAME=email@address >&2
#    echo >&2
#    echo and then >&2
#    echo >&2
#    echo source ~/.zshrc.local >&2
#    echo >&2
#    exit 1
#fi

bin/check-dotfiles-environment || exit 1

if (( ! $SKIP_COMPLETIONS )); then
    echo "Setting up completion scripts."

    setup-completion argocd
    setup-completion helm
    setup-completion istioctl
    setup-completion kind
    setup-completion kubectl
    #setup-completion kops

    if [[ -n "$GOPATH" && -d "$GOPATH/bin" ]]; then
        SKIP_PATTERNS=()
        if [[ -r ./skipped-completions.txt ]]; then
            while IFS= read -r pattern; do
                [[ -z "$pattern" || "$pattern" = \#* ]] && continue
                SKIP_PATTERNS+=("$pattern")
            done < ./skipped-completions.txt
        fi

        for cmd in "$GOPATH/bin/"*; do
            if [[ ! -x "$cmd" ]]; then
                continue
            fi

            cmd="$(basename "$cmd")"

            skip=0
            for pattern in "${SKIP_PATTERNS[@]}"; do
                if [[ "$cmd" = ${~pattern} ]]; then
                    skip=1
                    break
                fi
            done
            (( skip )) && continue

            setup-completion "$cmd"
        done
    fi
fi

echo "Installing dotfiles."

link-file bin ~/bin

link-file ackrc ~/.ackrc
tmpl-link-file tmux.conf ~/.tmux.conf

link-file colorist ~/.colorist

tmpl-file vimrc
link-file vim ~/.vim
link-file vim/init.vim ~/.vimrc
link-file vim $XDG_CONFIG_HOME/nvim
link-file ideavimrc ~/.ideavimrc

tmpl-link-file kitty.conf $XDG_CONFIG_HOME/kitty/kitty.conf

link-file zsh ~/.zsh
link-file zshrc ~/.zshrc
link-file zshenv ~/.zshenv

link-file gitignore ~/.gitignore

tmpl-link-file gitconfig ~/.gitconfig

tmpl-link-file offlineimap.sh ~/.offlineimap.sh
tmpl-link-file offlineimaprc ~/.offlineimaprc

link-file label-mail.yml ~/.label-mail.yml

tmpl-link-file muttrc ~/.muttrc
link-file mutt ~/.mutt
link-file mailcap ~/.mailcap
tmpl-link-file msmtprc ~/.msmtprc

tmpl-link-file signature ~/.signature

link-file repl.rc ~/.re.pl/repl.rc

link-file XCompose ~/.XCompose

tmpl-link-file minikube/offlineimap.yaml ~/.zostay-minikube/offlineimap.yaml

link-file rotate-music.yaml ~/.rotate-music.yaml

echo "Ensuring external tools."

# recon: tmux-native dashboard for Claude Code sessions. Used by the
# `workon` 3-pane layout (bottom-left pane). See README.md.
install-cargo-crate recon https://github.com/gavraz/recon
