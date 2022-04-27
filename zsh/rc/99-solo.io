# Final work hacks
if [ `cat $HOME/.dotfile-environment` = 'solo.io' ]; then
  export GOPATH="$HOME/go"
  export PATH="$PATH:$HOME/go/bin"
  export PATH="$HOME/.gloo-mesh/bin:$PATH"
  export PATH="/opt/homebrew/opt/protobuf@3.6/bin:$PATH"
  export PATH="/opt/homebrew/opt/openssl@1.1/bin:$PATH"

  export GOPRIVATE="github.com/solo-io"

  export ISTIO_VERSION=$(istioctl version -ojson | jq '.clientVersion.version' -r)

  export MallocNanoZone=0
  export GLOO_MESH_USE_KIND_IMAGE_V1_21=1

  if (($(ulimit -n) < 1000)); then
    ulimit -n 1000
  fi

  alias k=kubectl
  alias kmg="kubectl --context kind-mgmt-cluster"
  alias kc="kubectl --context kind-cluster-1"
  alias kc1="kubectl --context kind-cluster-1"
  alias kc2="kubectl --context kind-cluster-2"
fi

# vim: ft=zsh
