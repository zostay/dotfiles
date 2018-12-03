#!/usr/bin/env perl6
# Original Author: Todd Larason <jtl@molehill.org>
# Heavily modified by Andrew Sterling Hanenkamp.

use v6;

# colors 16-231 are a 6x6x6 color cube
for ^6 X ^6 X ^6 -> ($red, $green, $blue) {
    my $i = 16 + ($red * 36) + ($green * 6) + $blue;
    my $r = floor($red * 42.5);
    my $g = floor($green * 42.5);
    my $b = floor($blue * 42.5);
    #say "$i <- ($r, $g, $b)";
    printf("\e]4;%d;rgb:%2.2x/%2.2x/%2.2x\e\\", $i, $r, $g, $b);
}

# colors 232-255 are a grayscale ramp, intentionally leaving out
# black and white
for ^24 -> $gray {
    my $level = ($gray * 10) + 8;
    printf("\e]4;%d;rgb:%2.2x/%2.2x/%2.2x\e\\",
        232 + $gray, $level, $level, $level);
}

# display the colors

# first the system ones:
say "System colors:";
for ^8 -> $color {
    print "\e[48;5;{$color}m  ";
}
say "\e[0m";
for 8..^16 -> $color {
    print "\e[48;5;{$color}m  ";
}
say "\e[0m\n";

# now the color cube
say "Color cube, 6x6x6:";
for ^6 -> $green {
    for ^6 -> $red  {
        for ^6 -> $blue {
            my $color = 16 + ($red * 36) + ($green * 6) + $blue;
            print "\e[48;5;{$color}m  ";
        }
        print "\e[0m ";
    }
    print "\n";
}

# now the grayscale ramp
say "Grayscale ramp:";
for 232..255 -> $color {
    print "\e[48;5;{$color}m  ";
}
say "\e[0m";

