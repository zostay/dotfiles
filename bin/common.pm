package common;
use 5.10.1;

use strict;
use warnings;

use autodie;
use File::Path;

require Exporter;
our @ISA = qw( Exporter );

our @EXPORT_OK = qw(
    emkpath echdir esystem esymlink erename 
    %FG %BG %FX xyz_color
);

our %FX = (
    reset     => "\e[0m",
    bold      => "\e[01m", nobold      => "\e[22m",
    italic    => "\e[03m", noitalic    => "\e[23m",
    underline => "\e[04m", nounderline => "\e[24m",
    blink     => "\e[05m", noblink     => "\e[25m",
    reverse   => "\e[07m", noreverse   => "\e[27m",
);

our (%FG, %BG);
for my $color (0 .. 255) {
    my $pad_color = sprintf "%03d", $color;
    $FG{$color} = $FG{$pad_color} = "\e[38;5;${color}m";
    $BG{$color} = $BG{$pad_color} = "\e[48;5;${color}m";
}

if (not -t STDOUT) {
    $FX{$_} = '' for keys %FX;
    $FG{$_} = '' for keys %FG;
    $BG{$_} = '' for keys %BG;
}

sub xyz_color($$$) {
    my ($x, $y, $z) = @_;
    my $index = 16 + $x * 36 + $y * 6 + $z;
}

sub emkpath($) {
    say "$FG{167}mkpath $FG{179}@_$FX{reset}";
    mkpath($_[0]);
}

sub echdir($) {
    say "$FG{167}cd $FG{179}@_$FX{reset}";
    chdir $_[0];
}

sub esystem(@) {
    say "$FG{167}@_$FX{reset}";
    system(@_);
}

sub esymlink($$) {
    say "$FG{167}ln -s $FG{179}$_[0] $FG{181}$_[1]$FX{reset}";
    symlink $_[0], $_[1];
}

sub erename($$) {
    say "$FG{167}mv $FG{179}$_[0] $FG{181}$_[1]$FX{reset}";
    rename $_[0], $_[1];
}

1;
