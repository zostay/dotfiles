package Zostay;
use v5.14;
use warnings;

use File::Path;

use FindBin;
use lib "$FindBin::Bin/../bin/YAML-Tiny/lib";
use YAML::Tiny;

require Exporter;
our @ISA = qw( Exporter );

our @EXPORT_OK = qw(
    emkpath echdir esystem esymlink erename
    %FG %BG %FX xyz_color
    get_secret inject_secrets
    dotfiles_os
    dotfiles_environment
    dotfiles_config_raw
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
    system(@_) == 0 || die "cannot run: ", join(' ', @_), "\n";
}

sub esymlink($$) {
    say "$FG{167}ln -s $FG{179}$_[0] $FG{181}$_[1]$FX{reset}";
    symlink $_[0], $_[1];
}

sub erename($$) {
    say "$FG{167}mv $FG{179}$_[0] $FG{181}$_[1]$FX{reset}";
    rename $_[0], $_[1];
}

sub dotfiles_os {
    return $^O;
}

sub dotfiles_environment {
    if (@_) {
        open my $fh, '>', "$ENV{HOME}/.dotfile-environment"
            or die "cannot open .dotfile-environment: $!\n";
        print $fh "$_[0]\n";
        close $fh
            or die "cannot write .dotfile-environment: $!\n";
        return $_[0];
    }

    open my $fh, '<', "$ENV{HOME}/.dotfile-environment"
        or die "cannot open .dotfile-environment: $!\n";
    my $env = do { local $/; <$fh> };
    close $fh
        or die "cannot read .dotfile-environment: $!\n";

    chomp $env;
    return $env;
}

sub get_secret($) {
    my $name = shift;
    open my $fh, '-|', "$ENV{HOME}/bin/zostay-get-secret", $name
        or die "failed to start zostay-get-secret: $!\n";

    my $secret = do { local $/; <$fh> };
    chomp $secret;

    close $fh
        or die "failed to run zostay-get-secret ($?): $!\n";

    return $secret;
}

sub inject_secrets($;$) {
    my ($thing, $cache) = @_;
    $cache //= {};

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
    };

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

sub _merge_configs {
    my (@layers) = @_;

    # $layer1 = {
    #   app => {
    #       key1 => 'a',
    #       key3 => 'b',
    #   }
    # }
    # $layer2 = {
    #   app => {
    #      key1 => 'c',
    #      key2 => 'd',
    #   }
    # }
    #
    # $merged = {
    #   app => {
    #       key1 => 'c',
    #       key2 => 'd',
    #       key3 => 'b',
    #   }
    # }

    my $config = {};
    for my $layer (@layers) {
        for my $name (keys %$layer) {
            for my $key (%{ $layer->{ $name } }) {
                my $value = $layer->{ $name }{ $key };
                if (ref($value) eq 'HASH') {
                    $config->{ $name }{ $key } = +{ %$value };
                }
                elsif (ref($value) eq 'ARRAY') {
                    $config->{ $name }{ $key } = +{ @$value };
                }
                else {
                    $config->{ $name }{ $key } = $value;
                }
            }
        }
    }

    return $config;
}

sub dotfiles_config_raw {
    my ($name, $env, $os) = @_;

    $os  //= dotfiles_os();
    $env //= dotfiles_environment();

    my $config;
    if (-f "$ENV{HOME}/.dotfiles.yml") {
        $config = YAML::Tiny->read("$ENV{HOME}/.dotfiles.yml");
    }
    elsif (-f "dotfiles.yml") {
        $config = YAML::Tiny->read("dotfiles.yml");
    }
    else {
        die "unable to locate .dotfiles.yml or dotfiles.yml\n";
    }

    my $merged_config = _merge_configs(
        $config->[0]{oses}{'*'}            // {},
        $config->[0]{oses}{ $os }          // {},
        $config->[0]{environments}{'*'}    // {},
        $config->[0]{environments}{ $env } // {},
    );

    if ($name) {
        return $merged_config->{ $name };
    }
    else {
        return $merged_config;
    }
}

sub dotfiles_config {
    my ($name, $env, $os) = @_;
    return inject_secrets( dotfiles_config_raw($name, $env, $os) );
}

# vim: ts=4 sts=4 sw=4

1;
