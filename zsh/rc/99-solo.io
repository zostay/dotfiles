# Final work hacks
if [ `cat $HOME/.dotfile-environment` = 'solo.io' ]; then
  export GOPATH="$HOME/go"
  export PATH="$PATH:$HOME/go/bin"
  export PATH="$HOME/.gloo-mesh/bin:$PATH"
fi

# vim: ft=zsh
