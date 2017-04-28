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

Install FiraCode font from here:

    * <https://github.com/tonsky/FiraCode>

Install iTerm2 from here:

    * <https://www.iterm2.com/>

Add the FiraCode font to iTerm2.

# Mail

Add this to crontab if this is a mail checking machine:

    */15 * * * * ~/bin/label-mail > /dev/null
