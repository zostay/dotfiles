#!/bin/zsh

# Thanks, Frew, for the inspiration!

PATH="$PWD/bin:$PATH"
SKIP_SECRETS=0
SKIP_COMPLETIONS=0
while getopts "s" opt; do
    case $opt in
        c)
            SKIP_COMPLETIONS=1
            ;;
        s)
            SKIP_SECRETS=1
            ;;
    esac
done
shift $OPTIND-1

. ./functions.sh

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

    SECRETS_HERE=(GIT_EMAIL_HOME GIT_EMAIL_SPEAKEASY)

    if hash brew 2>/dev/null; then
        SECRETS_HERE+=(HOMEBREW_GITHUB_API_TOKEN)
    fi

    echo $SECRETS_HERE

    bin/zostay-pull-secrets $SECRETS_HERE
fi

if (( ! $SKIP_COMPLETIONS )); then
    echo "Setting up completion scripts."

    setup-completion argocd
    setup-completion helm
    setup-completion istioctl
    setup-completion kind
    setup-completion kubectl
    #setup-completion kops

    if [[ -n "$GOPATH" && -d "$GOPATH/bin" ]]; then
        for cmd in "$GOPATH/bin/"*; do
            if [[ ! -x "$cmd" ]]; then
                continue
            fi

            cmd="$(basename "$cmd")"

            [[ "$cmd" = "iferr" ]] && continue
            [[ "$cmd" = "forward-file" ]] && continue
            [[ "$cmd" = "gosec" ]] && continue
            [[ "$cmd" = "gotags" ]] && continue
            [[ "$cmd" = "gotestfmt" ]] && continue
            [[ "$cmd" = "kops" ]] && continue
            [[ "$cmd" = "label-mail" ]] && continue
            [[ "$cmd" = "label-message" ]] && continue
            [[ "$cmd" = "nasapod" ]] && continue
            [[ "$cmd" = "protoc-gen-apigw" ]] && continue
            [[ "$cmd" = "sqlboiler-"* ]] && continue
            [[ "$cmd" = "zap-cli" ]] && continue

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
