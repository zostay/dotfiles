package Zostay::Mail;
use v5.14;
use warnings;
use Moo;

use DDP;
use DateTime;
use File::Find::Rule;
use List::Util qw( any );
use YAML::Tiny;
use Zostay qw( dotfiles_environment );
use Zostay::Mail::Message;

our $MAILDIR = "$ENV{HOME}/Mail";
die "no Mail directory present" unless -d $MAILDIR;

our %LABEL_BOXES = (
    '\Inbox'     => 'INBOX',
    '\Trash'     => 'gmail.Trash',
    '\Important' => 'gmail.Important',
    '\Sent'      => 'gmail.Sent_Mail',
    '\Starred'   => 'gmail.Starred',
    '\Draft'     => 'gmail.Drafts',
);

our %BOX_LABELS = reverse %LABEL_BOXES;

has env => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_build_env',
);

sub _build_env {
    my ($self) = @_;
    dotfiles_environment();
}

has only_filter_recent => (is => 'rw');
has only_filter_since => (is => 'rw', lazy => 1, builder => "_build_only_filter_since");

sub _build_only_filter_since {
    my $self = shift;
    return undef unless $self->only_filter_recent;
    DateTime->now->subtract(%{ $self->only_filter_recent });
}

has _rules => (
    is          => 'ro',
    lazy        => 1,
    builder     => '_build__rules',
);

sub _build__rules {
    my ($self) = @_;

    my $config = YAML::Tiny->read("$ENV{HOME}/.label-mail.yml")->[0];
    my @RULES = (
        @{ $config->{'*'}  // [] },
        @{ $config->{$self->env} // [] },
    );

    if (-f "$ENV{HOME}/.label-mail.local.yml") {
        my $local = YAML::Tiny->read("$ENV{HOME}/.label-mail.local.yml")->[0];
        push @RULES, @{ $local // [] };
    }

    # Sanity check the rules
    for my $c (@RULES) {

        # MUST HAVE AN ACTION
        unless (defined $c->{label} or defined $c->{move} or defined $c->{clear} or defined $c->{forward}) {
            my $pretty_c = join ', ', map { "$_: $c->{$_}" } keys %$c;
            warn "RULE MISSING ACTION $pretty_c\n";
            next;
        }

        # Make sure to use the label form if I used a mailbox name
        for my $label (qw( label clear )) {
            next unless $c->{$label};

            my @k = $c->{$label};
            @k = @{ $k[0] } if @k == 1 && ref $k[0];

            for my $i (0 .. $#k) {
                $k[$i] =~ s{\.}{/}g;

                $k[$i] = $BOX_LABELS{ $k[$i] }
                    if defined $k[$i]
                   and defined $BOX_LABELS{ $k[$i] };
            }

            $c->{$label} = \@k;
        }

        # Make sure to use the folder name if I used a label form
        if (defined $c->{move}) {
            $c->{move} = $LABEL_BOXES{ $c->{move} }
                if defined $LABEL_BOXES{ $c->{move} };

            $c->{move} =~ s{/}{.}g;
        }
    }

    return \@RULES;
}

sub rules { @{ shift->_rules } }

sub messages {
    my ($self, $folder) = @_;

    my $messages = File::Find::Rule->file;

    # When only_filter_since, we only want to look at messages newer than the
    # date set in the setting.
    if (defined $self->only_filter_since) {
        my $epoch = $self->only_filter_since->epoch;
        warn "Only looking at message files modified since $epoch";
        $messages = $messages->mtime(">$epoch");
    }

    return map {
        Zostay::Mail::Message->new(
            file_name => $_,
        );
    } $messages->in(
        "$MAILDIR/$folder/new",
        "$MAILDIR/$folder/cur",
    );
}

sub message {
    my ($self, $folder, $file) = @_;

    for my $rd (qw( new cur )) {
        my $file_name = "$MAILDIR/$folder/$rd/$file";
        if (-f $file_name) {
            return Zostay::Mail::Message->new(
                file_name => $file_name,
            );
        }
    }

    return;
}

sub folder_rules {
    my ($self) = @_;

    my %folders;
    for my $c ($self->rules) {
        if ($c->{days} || ($c->{label} && any { $_ eq '\\Trash' } @{ $c->{label} }) || ($c->{mode} && $c->{move} eq 'gmail.Trash')) {
            $c->{okay_date} = DateTime->now->subtract(
                days => $c->{days} // 90,
            );
        }

        push @{ $folders{ $c->{folder} // '' } }, $c;

        if (defined $c->{move} && defined $c->{folder}) {
            my %and_clear_inbox = %$c;
            delete $and_clear_inbox{move};

            my %x = (
                %and_clear_inbox,
                folder => $c->{move},
                clear  => '\Inbox',
            );
            push @{ $folders{ $c->{move} } }, +{
                %and_clear_inbox,
                folder => $c->{move},
                clear  => '\Inbox',
            };
        }
    }

    %folders;
}

sub label_messages {
    my ($self) = @_;

    my %actions;
    my %folders = $self->folder_rules;
    for my $folder (keys %folders) {
        $self->label_folder_messages(\%actions, $folder, @{ $folders{ $folder } });
    }

    return %actions;
}

sub label_folder_messages {
    my ($self, $actions, $folder, @rules) = @_;

    for my $msg ($self->messages($folder)) {

        # Always skip the spam, drafts, sent, and trash folders
        next if $msg->folder eq 'gmail.Spam';
        next if $msg->folder eq 'gmail.Drafts';
        next if $msg->folder eq 'gmail.Trash';
        next if $msg->folder eq 'gmail.Sent_Mail';

        next unless $msg->text;

        # Purged, leave it be
        next if $msg->has_keyword('\Trash');

        for my $c (@rules) {
            my @actions = $msg->apply_rule($c);
            $actions->{ $_ }++ for @actions;
        }
    }
}

sub vacuum {
    my ($self, $log) = @_;
    $log //= sub {};

    opendir my $folderdh, "$MAILDIR" or die "cannot read $MAILDIR: $!";
    for my $folder (readdir $folderdh) {
        next if $folder eq '.';
        next if $folder eq '..';
        next unless -d "$MAILDIR/$folder";

        # Labeling errors: Foo, or \Important, or [ or ] or +Foo
        if ($folder =~ /,$ | ^\+ | ^\\ | ^(?:\[|\])$ | ^Drafts$ /x) {
            $log->("Dropping $folder");
            for my $msg ($self->messages($folder)) {
                my $folder = $msg->best_alternate_folder;
                $msg->move_to($folder);
                $msg->remove_keyword($folder);
                $msg->save;
                $log->(sprintf " -> Moved %s to %s", $msg->basename, $folder);
            }

            for (qw( new cur tmp )) {
                rmdir "$MAILDIR/$folder/$_"
                    or warn "cannot delete $MAILDIR/$folder/$_: $!";
            }
            rmdir "$MAILDIR/$folder"
                or warn "cannot delete $MAILDIR/$folder: $!";
        }

        else {
            $log->("Searching $folder for broken Keywords.");
            for my $msg ($self->messages($folder)) {
                my $change = 0;

                # Cleanup unwanted chars in our keywords
                if ($msg->has_nonconforming_keywords) {
                    $log->("Fixing non-conforming keywords.");
                    $msg->cleanup_keywords;
                    $change++;
                }

                # Something went wrong somewhere
                if ($msg->has_keyword('Network')
                || $msg->has_keyword('Pseudo-Junk.Social')) {
                    $log->("Fixing Pseudo-Junk.Social Network to Pseudo-Junk.Social_Network.");
                    $change++;

                    $msg->remove_keyword('Network');
                    $msg->remove_keyword('Pseudo-Junk.Social');
                    $msg->add_keyword('Pseudo-Junk.Social_Network');
                }

                $msg->save if $change;
            }
        }
    }
    closedir $folderdh;
}

1;

# vim: ts=4 sts=4 sw=4
