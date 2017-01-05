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

Install local packages:

    ./packages.sh

## macOS

Install Powerline font from here:

    * <https://github.com/powerline/fonts/tree/master/DroidSansMono>

Install iTerm2 from here:

    * <https://www.iterm2.com/>

Add the Powerline font to iTerm2.
