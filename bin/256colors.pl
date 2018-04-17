#!/usr/bin/env perl
# Original Author: Todd Larason <jtl@molehill.org>
# Heavily modified by Andrew Sterling Hanenkamp.

use v5.20;
use warnings;

# colors 16-231 are a 6x6x6 color cube
for my $red (0 .. 5) {
    for my $green (0 .. 5) {
        for my $blue (0 .. 5) {
            my $i = 16 + ($red * 36) + ($green * 6) + $blue;
            my $r = int ($red * 42.5);
            my $g = int ($green * 42.5);
            my $b = int ($blue * 42.5);
            say "$i <- ($r, $g, $b)";
            printf("\e]4;%d;rgb:%2.2x/%2.2x/%2.2x\e\\", $i, $r, $g, $b);
        }
    }
}

# colors 232-255 are a grayscale ramp, intentionally leaving out
# black and white
for my $gray (0 .. 23) {
    my $level = ($gray * 10) + 8;
    printf("\e]4;%d;rgb:%2.2x/%2.2x/%2.2x\e\\",
	   232 + $gray, $level, $level, $level);
}


# display the colors

# first the system ones:
print "System colors:\n";
for my $color (0 .. 7) {
    print "\e[48;5;${color}m  ";
}
print "\e[0m\n";
for my $color (8 .. 15) {
    print "\e[48;5;${color}m  ";
}
print "\e[0m\n\n";

# now the color cube
print "Color cube, 6x6x6:\n";
for my $green (0 .. 5) {
    for my $red (0 .. 5) {
        for my $blue (0 .. 5) {
            my $color = 16 + ($red * 36) + ($green * 6) + $blue;
            print "\e[48;5;${color}m  ";
        }
        print "\e[0m ";
    }
    print "\n";
}


# now the grayscale ramp
print "Grayscale ramp:\n";
for my $color (232 .. 255) {
    print "\e[48;5;${color}m  ";
}
print "\e[0m\n";
