#!/bin/zsh

DOCKER_DIR=docker

docker build $DOCKER_DIR/perl -t zostay/dotfiles-perl
docker push zostay/dotfiles-perl
