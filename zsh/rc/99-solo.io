# Final work hacks
if [ `cat $HOME/.dotfile-environment` = 'solo.io' ]; then
  export GOPATH="$HOME/go"
  export PATH="$PATH:$HOME/go/bin"
  export PATH="$HOME/.gloo-mesh/bin:$PATH"

  export GOPRIVATE="github.com/solo-io"

  export ISTIO_VERSION=$(istioctl version -ojson | jq '.clientVersion.version' -r)
  export MallocNanoZone=0
fi

# vim: ft=zsh
