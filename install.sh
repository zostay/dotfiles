#!/bin/zsh

# Thanks, Frew!

echo "running rc installer"

function __mkdir { if [[ ! -d $1 ]]; then mkdir -p $1; fi }
function link-file { __mkdir "${2:h}"; rm -rf "$2"; ln -s "$PWD/$1" "$2" }
function copy-file { __mkdir "${2:h}"; rm -rf "$2"; cp "$PWD/$1" "$2" }

for x in vimrc vim do
    link-file $x ~/.$x
done
