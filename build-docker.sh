#!/bin/zsh

DOCKER_DIR=docker

docker build $DOCKER_DIR/perl -t zostay/dotfiles-perl
docker push zostay/dotfiles-perl

docker build $DOCKER_DIR/raku -t zostay/dotfiles-raku
docker push zostay/dotfiles-raku
