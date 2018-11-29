#!/bin/zsh

# Thanks, Frew, for the inspiration!

PATH="$PWD/bin:$PATH"
SKIP_SECRETS=0
while getopts "s" opt; do
    case $opt in
        s)
            SKIP_SECRETS=1
            ;;
    esac
done
shift $OPTIND-1

function __mkdir { if [[ ! -d $1 ]]; then mkdir -p $1; fi }
function backup-file {
    __mkdir "$HOME/.dotfiles.bak"
    if [[ -h "$1" ]]; then # clobber symlinks
        rm -rf "$1"
    elif [[ -e "$1" ]]; then # backup anything else
        mv "$1" "$HOME/.dotfiles.bak/${1:t}"
    fi
}
function link-file { __mkdir "${2:h}"; backup-file "$2"; ln -s "$PWD/$1" "$2" }
function copy-file { __mkdir "${2:h}"; backup-file "$2"; cp "$PWD/$1" "$2" }
function tmpl-file { __mkdir ".build"; template-dotfile $DOTFILE_ENV "$1" ".build/$1" }
function tmpl-link-file { tmpl-file "$1"; [[ -f ".build/$1" ]] && link-file ".build/$1" "$2" }

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

if hash lpass 2> /dev/null && [[ -z "$LPASS_USERNAME" ]]; then
    echo You must put the following line into .zshrc.local: >&2
    echo >&2
    echo export LPASS_USERNAME=email@address >&2
    echo >&2
    echo and then >&2
    echo >&2
    echo source ~/.zshrc.local >&2
    echo >&2
    exit 1
fi

bin/check-dotfiles-environment || exit 1

if (( ! $SKIP_SECRETS )); then
    echo "Pulling secrets."

    SECRETS_HERE=(GIT_EMAIL_HOME GIT_EMAIL_ZIPRECRUITER)

    if hash brew 2>/dev/null; then
        SECRETS_HERE+=(HOMEBREW_GITHUB_API_TOKEN)
    fi

    echo $SECRETS_HERE

    bin/zostay-pull-secrets $SECRETS_HERE
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
