if hash kubectl 2> /dev/null; then
    eval "$(kubectl completion zsh)"
fi

if hash kops 2> /dev/null; then
    eval "$(kops completion zsh)"
fi
