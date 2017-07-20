#!/bin/zsh

if [[ ! -d ~/.rakudobrew ]]; then
    git clone https://github.com/tadzik/rakudobrew ~/.rakudobrew
fi

export PATH=~/.rakudobrew/bin:$PATH

rakudobrew init
rakudobrew build moar
rakudobrew build panda

perl6 packages.p6

preferred_perl=5.24.2

cpanm=(
    App::Ack
    App::Colorist
    DateTime
    Date::Parse
    DDP
    Email::MIME
    File::Find::Rule
    List::Util
    Try::Tiny
    YAML::Tiny
)

# install plenv
if [ ! -d ~/.plenv ]; then
    git clone https://github.com/tokuhirom/plenv.git ~/.plenv
    git clone https://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build/
fi

export PATH="$HOME/.plenv/shims:$HOME/.plenv/bin:$PATH"

if ! plenv versions | grep $preferred_perl >/dev/null; then
    plenv install $preferred_perl
    plenv global $preferred_perl
    plenv rehash
fi

plenv install-cpanm
for pkg in $cpanm; do
    cpanm --notest $pkg
done

if hash brew 2> /dev/null; then
    brew update
    brew install lastpass-cli
    brew install msmtp
    brew install neomutt/homebrew-neomutt/neomutt --with-notmuch-patch
    brew install reattach-to-user-namespace
    brew install w3m
fi

# vim: ts=4 sts=4 sw=4
