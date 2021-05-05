if [ `uname` = "Darwin" ]; then
    alias ls="ls -G"
elif [ `uname` = "Linux" ]; then
    #umask 077

    alias ls='ls --color=auto'
fi

# UTF-8 terminal please
export LC_ALL="en_US.UTF-8"
export LANG="en_US.UTF-8"
stty iutf8

alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

if hash nvim 2> /dev/null; then
    export EDITOR="nvim"
    alias vim=nvim
else
    export EDITOR="vim"
fi

if [ `cat $HOME/.dotfile-environment` = 'ziprecruiter' ]; then
  export GOPATH="$HOME/go"
else
  export GOPATH="$HOME/projects/go"
fi

# if hash perl6 2> /dev/null; then
#   MOAR_BINDIR=`perl6 -V | grep moar::bindir | cut -d= -f2`
#   MOAR_SHAREDIR=`perl6 -V | grep perl6::libdir | cut -d= -f2`
# fi

if [ -d $HOME/perl5/perlbrew/etc ]; then
  . $HOME/perl5/perlbrew/etc/bashrc
fi

# strip out all the paths outside of home, we will replace them
paths=( $(echo $PATH | sed 's/:/ /g') )
PATH=""
for thispath in $paths; do
    if [ "${thispath#$HOME}" = "$thispath" ]; then
        PATH="$PATH:$thispath"
    fi
done
PATH="${PATH:1}"

post_paths=(
    $MOAR_BINDIR
    $MOAR_SHAREDIR/perl6/site/bin
    /usr/local/Cellar/rakudo-star/bin
    /opt/local/bin
    /usr/local/sbin
    /sw/bin
    /snap/bin
    /opt/X11/bin
)

pre_paths=(
    $GOPATH/bin
    $HOME/bin
    $HOME/local/bin
    $HOME/Documents/android/platform-tools
    $HOME/Documents/android/tools
    $HOME/Documents/arm-cs-tools/bin
    $HOME/pebble-dev/PebbleSDK-current/bin
    $HOME/.rakudobrew/bin
    $HOME/.rakudobrew/moar-nom/install/share/perl6/site/bin
    $HOME/zscript/bin
    /usr/local/opt/ruby/bin
    $HOME/.yarn/bin
    $HOME/.platformio/penv/bin
)

for add_path in $post_paths; do
    if [ -d "$add_path" ]; then
        if [ "${PATH#*$add_path}" = "$PATH" ]; then
            PATH="$PATH:$add_path"
        fi
    fi
done

for add_path in $pre_paths; do
    if [ -d "$add_path" ]; then
        if [ "${PATH#*$add_path}" = "$PATH" ]; then
            PATH="$add_path:$PATH"
        fi
    fi
done

export PATH
export ZOSTAY_PATH_SETUP=1

bindkey -v

# Make sure Ubuntu does not eff up my up/down arrows
bindkey -M viins "$terminfo[cuu1]" up-line-or-history
bindkey -M viins "$terminfo[kcuu1]" up-line-or-history
bindkey -M viins "$terminfo[kcud1]" down-line-or-history
bindkey -M viins "${terminfo[kcuu1]/O/[}" up-line-or-history
bindkey -M viins "${terminfo[kcud1]/O/[}" down-line-or-history


setopt correct cdablevars autolist
setopt autocd recexact histignoredups
setopt noclobber autopushd extendedglob
setopt globcomplete bareglobqual prompt_subst
setopt appendhistory nullglob incappendhistory
setopt hist_ignore_space

export HISTSIZE=10000
export SAVEHIST=10000
export HISTFILE=$HOME/.zhistory

man() {
    local OPTIND o
    if getopts "k" o; then
        /usr/bin/man "$@"
    else
        /usr/bin/man -w "$@" || return 1;
        vim -R -c "Man $1 $2" -c "bdelete 1";
    fi
}

info() { vim -R -c "Man $1.i" -c "bdelete 1"; }

pd() {
    if perldoc "$1" >& /dev/null; then
        vim -R -c "Man $1" -c "bdelete 1"
    else
        echo "Module not found";
    fi
}

pf() {
    if perldoc -f "$1" >& /dev/null; then
        vim -R -c "Man $1.pl" -c "bdelete 1";
    else
        echo "Function not found";
    fi
}

pm() { vim `perldoc -l $1`; }

alias tmux="tmux -2"

if [[ -d $HOME/.colorist ]]; then
    . $HOME/.colorist/bashrc
fi

. $HOME/.zsh/functions/spectrum
. $HOME/.zsh/prompt

if [[ -d /usr/local/share/zsh/site-functions ]]; then
  fpath=($HOME/.zsh/comp /usr/local/share/zsh/site-functions $fpath)
fi

autoload -Uz compinit
compinit -u

zmodload -a colors
zmodload -a autocomplete
zmodload -a complist

zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' ignored-patterns '.irssi|.vim'

# . ~/.zsh/svk-completion
# . ~/.zsh/gitc-completion

if [ -d /usr/local/lib/node_modules ]; then
    export NODE_PATH=/usr/local/lib/node_modules
fi

alias pl='perldoc -l'
alias less='less -F'
alias grep='grep --color=auto'
alias unscram='perl -wle "print qq|\cO|"'
alias irc='autossh -n irssi qubling'

for RC in $HOME/.zsh/rc/*(n); do
    source $RC
done

if [[ -d /var/lib/snapd/desktop ]]; then
    export XDG_DATA_DIRS="$XDG_DATA_DIRS:/var/lib/snapd/desktop/"
fi

if [ -e $HOME/.zshrc.local ]; then
    source $HOME/.zshrc.local;
fi

export PERL6LIB="$HOME/perl6/lib"
