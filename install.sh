#!/bin/zsh

# Thanks, Frew, for the inspiration!

echo "Installing dotfiles."

function __mkdir { if [[ ! -d $1 ]]; then mkdir -p $1; fi }
function link-file { __mkdir "${2:h}"; rm -rf "$2"; ln -s "$PWD/$1" "$2" }
function copy-file { __mkdir "${2:h}"; rm -rf "$2"; cp "$PWD/$1" "$2" }
function tmpl-file { __mkdir ".build"; template-dotfile $DOTFILE_ENV "$1" ".build/$1" }
function tmpl-link-file { tmpl-file "$1"; link-file "$1" "$2" }

XDG_CONFIG_HOME=${XDG_CONFIG_HOME:=$HOME/.config}
if [[ -n $* ]]; then
    DOTFILE_ENV=$1;
    echo $DOTFILE_ENV >! ~/.dotfile-environment
    shift;
else
    DOTFILE_ENV=$(cat ~/.dotfile-environment)
fi

link-file bin ~/bin

link-file ackrc ~/.ackrc
link-file tmux.conf ~/.tmux.conf

link-file colorist ~/.colorist

link-file vim ~/.vim
link-file vim/init.vim ~/.vimrc
link-file vim $XDG_CONFIG_HOME/nvim

link-file zsh ~/.zsh
link-file zshrc ~/.zshrc
link-file zshenv ~/.zshenv

link-file gitignore ~/.gitignore

tmpl-link-file gitconfig ~/.gitconfig


