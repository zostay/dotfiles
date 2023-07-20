# Installation

Clone this repo and initialize it:

    git clone git@github.com:zostay/dotfiles.git
    cd dotfiles
    git submodule init
    git submodule update

Add this to `~/.zshrc.local`

    export LPASS_USERNAME="username"

Load the into the current environment:

    source ~/.zshrc.local

Run:

    ./install.sh <environment>

## macOS

Install [Homebrew](https://github.com/Homebrew/brew/blob/master/docs/Installation.md#installation).

Install FiraCode font from here:

* <https://github.com/tonsky/FiraCode>

# Install My Packages

Install local packages:

    ./packages.sh

# Mail

Add this to crontab if this is a mail checking machine:

    */15 * * * * ~/bin/label-mail > /dev/null
