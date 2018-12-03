#!/usr/bin/env perl6
use v6;

my constant $off = 32;
my constant $n   = 256 / $off;
my constant $cube-seq = 0, |($off-1, 2*$off-1 ... 256-1);

say "Color cube, $n x $n x $n:";
for $cube-seq -> $green {
    for $cube-seq -> $red {
        for $cube-seq -> $blue {
          print "\e[48;2;{$red};{$green};{$blue}m  ";
        }
        print "\e[0m ";
    }
    print "\n";
}

