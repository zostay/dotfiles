package Zostay;
use v5.14;
use warnings;

use File::Path;

use lib "$ENV{HOME}/bin/YAML-Tiny/lib";
use YAML::Tiny;

require Exporter;
our @ISA = qw( Exporter );

our @EXPORT_OK = qw(
    emkpath echdir esystem esymlink erename
    %FG %BG %FX xyz_color
    get_secret inject_secrets
    dotfiles_environment
    dotfiles_config
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
    system(@_) == 0 || die "cannot run: ", join(' ', @_);
}

sub esymlink($$) {
    say "$FG{167}ln -s $FG{179}$_[0] $FG{181}$_[1]$FX{reset}";
    symlink $_[0], $_[1];
}

sub erename($$) {
    say "$FG{167}mv $FG{179}$_[0] $FG{181}$_[1]$FX{reset}";
    rename $_[0], $_[1];
}

sub dotfiles_environment {
    if (@_) {
        open my $fh, '>', "$ENV{HOME}/.dotfile-environment"
            or die "cannot open .dotfile-environment: $!";
        print $fh "$_[0]\n";
        close $fh
            or die "cannot write .dotfile-environment: $!";
        return $_[0];
    }

    open my $fh, '<', "$ENV{HOME}/.dotfile-environment"
        or die "cannot open .dotfile-environment: $!";
    my $env = do { local $/; <$fh> };
    close $fh
        or die "cannot read .dotfile-environment: $!";

    chomp $env;
    return $env;
}

sub get_secret($) {
    my $secret = shift;
    open my $fh, '-|', "$ENV{HOME}/bin/zostay-get-secret", $secret
        or die "failed to start zostay-get-secret: $!";

    my $secret = do { local $/; <$fh> };

    close $fh
        or die "failed to run zostay-get-secret: $!";

    return $secret;
}

sub inject_secrets($;$) {
    my ($thing, $cache) = @_;

    my $cache //= {};
    my $get_secret = sub {
        my $name = shift;
        if ($cache->{ $name }) {
            return $cache->{ $name };
        }
        else {
            return $cache->{ $name } = get_secret($name);
        }
    };

    my $inject_secret = sub {
        my ($ref) = @_;
        my $value = $$ref;
        if (ref $value eq 'HASH') {
            my ($s, $n) = %$value;
            if ($s eq '__SECRET__') {
                $$ref = $get_secret->($n);
            }
            else {
                inject_secrets($value, $cache);
            }
        }
        elsif (ref $value eq 'ARRAY') {
            inject_secrets($value, $cache);
        }
    }

    if (ref $thing eq 'HASH') {
        for my $key (keys %$thing) {
            $inject_secret->(\$thing->{ $key });
        }
    }
    elsif (ref $thing eq 'ARRAY') {
        for my $i (0 .. $#$thing) {
            $inject_secret->(\$thing->[ $i ]);
        }
    }

    return $thing;
}

sub dotfiles_config($;$) {
    my ($name, $env) = @_;

    $env //= dotfiles_environment();

    die "invalid name" unless $name;

    my $config = YAML::Tiny->read("$ENV{HOME}/.dotfiles.yml");

    return inject_secrets($config->{ $env }{ $name });
}

1;
