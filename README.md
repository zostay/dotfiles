# Installation

Clone this repo and initialize it:

    git clone git@github.com:zostay/dotfiles.git
    cd dotfiles
    git submodule init
    git submodule update

Add my email address to `~/.zshrc.local`

    export LPASS_USERNAME="username"

Load the into the current environment:

    source ~/.zshrc.local

Run:

    ./install.sh <environment>

