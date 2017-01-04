#!/bin/zsh

preferred_perl=5.24.0

cpanm=(
    DateTime
    Date::Parse
    DDP
    Email::MIME
    File::Find::Rule
    List::Util
    YAML::Tiny
)

# install plenv
if [ ! -d ~/.plenv ]; then
    git clone https://github.com/tokuhirom/plenv.git ~/.plenv
fi
if ! plenv versions | grep $preferred_perl >/dev/null; then
    plenv install $preferred_perl
    plenv global $preferred_perl
    plenv install-cpanm
    plenv rehash
fi

for pkg in $cpanm; do
    cpanm --notest $pkg
done
