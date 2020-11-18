package Zostay::Mail::Message;
use v5.24;
use warnings;
use Moo;

use DDP;
use DateTime;
use Date::Parse qw( str2time );
use Email::Address;
use Email::MIME;
use Email::Sender::Simple qw( sendmail );
use Email::Sender::Transport::SMTP;
use List::Util qw( all none );
use Try::Tiny;

has debug => (is => 'rw', default => 0);
has dry_run => (is => 'rw', default => 0);

has file_name => ( is => 'rw' );
has file_parts => ( is => 'ro', lazy => 1, builder => '_build_file_parts' );
has folder => ( is => 'rw', lazy => 1, builder => '_build_folder' );
has rd => ( is => 'ro', lazy => 1, builder => '_build_rd' );
has basename => ( is => 'ro', lazy => 1, builder => '_build_basename' );

# This is dirty and ugly and I don't like it and it's wrong.
my $FROM_EMAIL = `$ENV{HOME}/bin/zostay-get-secret GIT_EMAIL_HOME`;
my $SASL_USER  = `$ENV{HOME}/bin/zostay-get-secret LABEL_MAIL_USERNAME`;
my $SASL_PASS  = `$ENV{HOME}/bin/zostay-get-secret LABEL_MAIL_PASSWORD`;

sub _build_file_parts {
    my $self = shift;
    my $short_name = substr $self->file_name, length($Zostay::Mail::MAILDIR) + 1;
    [ split '/', $short_name ]
}

sub _build_folder   { shift->file_parts->[0] }
sub _build_rd       { shift->file_parts->[1] }
sub _build_basename { shift->file_parts->[2] }

has text => ( is => 'ro', lazy => 1, builder => '_build_text' );

sub _build_text {
    my $self = shift;

    my $msg_txt = '';
    try {
        open my $msg_fh, '<', $self->file_name or die sprintf "cannot open %s: %s", $self->file_name, $!;
        $msg_txt = do { local $/; <$msg_fh> };
        close $msg_fh;
    }
    catch {
        warn $_;
    };

    $msg_txt;
}

has mime => ( is => 'ro', lazy => 1, builder => '_build_mime' );

sub _build_mime {
    my $self = shift;
    Email::MIME->new($self->text);
}

has date => ( is => 'ro', lazy => 1, builder => '_build_date' );

sub _build_date {
    my $self = shift;

    my $time = str2time($self->mime->header_str('Date'));
    unless (defined $time) {
        warn sprintf "Illegal date in message %s", $self->file_name;
        return;
    }
    DateTime->from_epoch(epoch => $time);
}

has _keywords => ( is => 'ro', lazy => 1, builder => '_build__keywords' );

sub _build__keywords {
    my $self = shift;

    my $keywords = $self->mime->header_str('Keywords');
    my @keywords   = $keywords ? split(/[\s,]+/, $keywords) : ();
    my %keywords   = map { $_ => 1 } @keywords;
    \%keywords;
}

# Returns true if the Keywords contains unwanted characters like commas
sub has_nonconforming_keywords {
    my $self = shift;
    my $keywords = $self->mime->header_str('Keywords');
    return scalar $keywords =~ / [^\w.-\/] /;
}

sub keywords { sort keys %{ shift->_keywords } }

# Returns false if no keywords given.
# Returns true if this message has all given keywords.
# Returns false otherwise.
sub has_keyword {
    my $self = shift;
    my @k = @_;
    @k = @{ $k[0] } if @k == 1 && ref $k[0];
    return '' unless @k;
    return all { $self->_keywords->{$_} } @k;
}

# Returns false is no keywords given.
# Returns true if this message is missing all given keywords.
# Returns false otherwise.
sub missing_keyword {
    my $self = shift;
    my @k = @_;
    @k = @{ $k[0] } if @k == 1 && ref $k[0];
    return '' unless @k;
    return none { $self->_keywords->{$_} } @k;
}

sub _update_mime_keywords {
    my $self = shift;
    $self->mime->header_str_set(
        Keywords => join(' ', $self->keywords)
    );
}

sub cleanup_keywords {
    my $self = shift;
    $self->_update_mime_keywords;
}

sub add_keyword {
    my $self = shift;
    my @k = @_;
    @k = @{ $k[0] } if @k == 1 && ref $k[0];

    return unless @k > 0;

    for my $keyword (@k) {
        $keyword = $Zostay::Mail::BOX_LABELS{ $keyword }
            if defined $Zostay::Mail::BOX_LABELS{ $keyword };

        $self->_keywords->{ $keyword }++;
    }

    $self->_update_mime_keywords;
}

sub remove_keyword {
    my $self = shift;
    my @k = @_;
    @k = @{ $k[0] } if @k == 1 && ref $k[0];

    return unless @k > 0;

    for my $keyword (@k) {
        $keyword = $Zostay::Mail::BOX_LABELS{ $keyword }
            if defined $Zostay::Mail::BOX_LABELS{ $keyword };

        delete $self->_keywords->{ $keyword };
    }

    $self->_update_mime_keywords;
}

has _from => ( is => 'ro', lazy => 1, builder => '_build__from' );
has _to => ( is => 'ro', lazy => 1, builder => '_build__to' );
has _sender => ( is => 'ro', lazy => 1, builder => '_build__sender' );

sub _build__from {
    my $self = shift;
    [ Email::Address->parse($self->mime->header_str('From')) ]
}

sub _build__to {
    my $self = shift;
    [ Email::Address->parse($self->mime->header_str('To')) ]
}

sub _build__sender {
    my $self = shift;
    [ Email::Address->parse($self->mime->header_str('Sender')) ]
}

sub from { @{ shift->_from } }
sub to { @{ shift->_to } }
sub sender { @{ shift->_sender } }

sub apply_rule {
    my ($self, $c) = @_;

    my @actions;

    # Safeguard to prevent rules with no tests from affecting all
    my $tests = 0;

    my @skip_tests = (
        sub {
            my ($self, $c) = @_;
            return (0, 'not labeling')            unless defined $c->{label};
            return (0, 'missing possible labels') unless $self->has_keyword($c->{label});
            return (1, 'already labeled as such');
        },

        sub {
            my ($self, $c) = @_;
            return (0, 'not clearing')            unless defined $c->{clear};
            return (0, 'labels to clear not set') unless $self->missing_keyword($c->{clear});
            return (1, 'not labeled as such');
        },

        sub {
            my ($self, $c) = @_;
            return (0, 'not moving')              unless defined $c->{move};
            return (0, 'in a different folder')   unless $self->folder eq $c->{move};
            return (1, 'in the same folder');
        },

        sub {
            my ($self, $c) = @_;
            return (1, 'do not modify \Starred') if $self->has_keyword('\Starred');
            return (0, 'not \Starred');
       },
    );

    my @rule_tests = (
        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no okay date') unless defined $c->{okay_date};
            $$tests++;
            my $okay_date = $c->{okay_date};
            return (1, 'message is more recent than okay date') if DateTime->compare($self->date, $okay_date) < 0;
            return (0, 'message is older than okay date');
        },

        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no from test') unless defined $c->{from};
            $$tests++;
            return (0, 'message has no From header') unless $self->from;
            return (0, 'message From header does not match from test') if none { $_->address eq $c->{from} } $self->from;
            return (1, 'message From header matches from test');
        },

        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no from domain test') unless defined $c->{from_domain};
            $$tests++;
            return (0, 'message has no From header') unless $self->from;
            return (0, 'message From header does not match from domain test') if none { $_->address =~ /@\Q$c->{from_domain}\E$/i } $self->from;
            return (1, 'message From header matches from domain test');
        },

        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no to test') unless defined $c->{to};
            $$tests++;
            return (0, 'message has no To header') unless $self->to;
            return (0, 'message To header does not match to test') if none { $_->address eq $c->{to} } $self->to;
            return (1, 'message To header matches to test');
        },

        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no to domain test') unless defined $c->{to_domain};
            $$tests++;
            return (0, 'message has no To header') unless $self->to;
            return (0, 'message To header does not match to tests') if none { $_->address =~ /@\Q$c->{to_domain}\E$/ } $self->to;
            return (1, 'message To header matches to domain test');
        },

        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no sender test') unless defined $c->{sender};
            $$tests++;
            return (0, 'message Sender header does not match sender test') if none { $_->address eq $c->{sender} } $self->sender;
            return (1, 'message Sender header matches sender test');
        },

        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no exact subject test') unless defined $c->{subject};
            $$tests++;
            my $subject = $self->mime->header_str('Subject');
            return (0, 'message Subject does not exactly match subject test') unless $c->{subject} eq $subject;
            return (1, 'message Subject exactly matches subject test');
        },

        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no folded case subject test') unless defined $c->{isubject};
            $$tests++;
            my $subject = $self->mime->header_str('Subject');
            return (0, 'message Subject does not match folded case of subject test') unless fc $c->{isubject} eq fc $subject;
            return (1, 'message Subject matches folded case of subject test');
        },

        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no subject contains test') unless defined $c->{subject_contains};
            $$tests++;
            my $subject = $self->mime->header_str('Subject');
            return (0, 'message Subject fails contains subject test') unless $subject =~ /\Q$c->{subject_contains}\E/;
            return (1, 'message Subject passes contains subject test');
        },

        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no subject contains subject folded case test') unless defined $c->{subject_icontains};
            $$tests++;
            my $subject = $self->mime->header_str('Subject');
            return (0, 'message Subject fails contains subject folded case test') unless $subject =~ /\Q$c->{subject_icontains}\E/i;
            return (1, 'message Subject passes contains subject folded case test');
        },

        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no contains anywhere test') unless defined $c->{contains};
            $$tests++;
            return (0, 'message fails contains anywhere test') unless $self->text =~ /\b\Q$c->{contains}\E\b/;
            return (1, 'message passes contains anywhere test');
        },

        sub {
            my ($self, $c, $tests) = @_;
            return (1, 'no contains anywhere folded case test') unless defined $c->{icontains};
            $$tests++;
            return (0, 'message fails contains anywhere folded case test') unless $self->text =~ /\b\Q$c->{icontains}\E\b/i;
            return (1, 'message passes contains anywhere folded case test');
        },

    );

    my ($fail, @passes);
    for my $skippable (@skip_tests) {
        my ($skip, $msg) = $skippable->($self, $c);

        if (!$skip) {
            push @passes, $msg;
        }
        else {
            $fail = $msg;
            last;
        }
    }

    return if $fail;

    for my $applies (@rule_tests) {
        my ($pass, $msg) = $applies->($self, $c, \$tests);

        if ($pass) {
            push @passes, $msg;
        }
        else {
            $fail = $msg;
        }
    }

    # DEBUGGING
    if ($self->debug) {
        if ($fail) {
            warn "FAILED: $fail.\n";
        }

        if (@passes && !$fail || $self->debug > 1) {
            warn "PASSES: ", join(', ', @passes), ".\n"
        }
    }

    return if $fail;
    return unless $tests > 0;

    my $action;

    # Add a label
    if (defined $c->{label}) {
        $self->add_keyword($c->{label});
        if (ref $c->{label}) {
            push @actions, "Labeled $_" for @{ $c->{label} };
        }
        else {
            push @actions, "Labeled $c->{label}";
        }
    }

    # Remove a label
    if (defined $c->{clear}) {
        $self->remove_keyword($c->{clear});
        if (ref $c->{clear}) {
            push @actions, "Cleared $_" for @{ $c->{clear} };
        }
        else {
            push @actions, "Cleared $c->{clear}";
        }

    }

    # Forward email to an address
    if (defined $c->{forward}) {
        $self->forward_to($c->{forward}) unless $self->dry_run;
        push @actions, "Forwarded $c->{forward}";
    }

    # Write the message back with changes
    if (@actions) {
        $self->save unless $self->dry_run;
    }

    # Move to a different folder
    if (defined $c->{move}) {
        $self->move_to($c->{move}) unless $self->dry_run;
        push @actions, "Moved $c->{move}";
    }

    return @actions;
}

my $transport = try {
    Email::Sender::Transport::SMTP->new({
        host          => 'smtp.gmail.com',
        port          => 587,
        ssl           => 'starttls',
        sasl_username => $SASL_USER,
        sasl_password => $SASL_PASS,
    });
}
catch {
    warn $_;
};

sub forward_to {
    my ($self, $to) = @_;

    try {

        die "Unable to forward because SMTP transport is not configured."
            unless defined $transport;

        # allow "foo@gmail.com" or [ qw(foo@gmail.com bar@gmail.com) ]
        $to = [ $to ] unless ref $to;
        my %to = map { $_ => 1 } @$to;

        # We only want to forward matched messages a single time! We use the
        # X-Zostay-Forwarded header to record and monitor what has been forwarded
        # and what has not been.
        my $forwarded_already = $self->mime->header_str('X-Zostay-Forwarded');
        my %forwarded_emails;
        if (defined $forwarded_already) {
            %forwarded_emails = map { $_ => 1 } split /\s+,\s+/, $forwarded_already;
        }

        for my $email_already_hit (keys %to) {
            if ($forwarded_emails{ $email_already_hit }) {
                delete $to{ $email_already_hit };
            }
        }

        # If we already forwarded to everyone in the list, skip actually forwarding.
        return unless keys %to;

        $to = [ keys %to ];

        sendmail($self->mime, {
            to        => $to,
            from      => $FROM_EMAIL,
            transport => $transport,
        });

        my %all_emails = (%to, %forwarded_emails);
        $self->mime->header_str_set(
            'X-Zostay-Forwarded' => join(', ', sort keys %all_emails),
        );

    }

    catch {
        warn $_;
    };
}

sub move_to {
    my ($self, $folder) = @_;

    $folder = $Zostay::Mail::LABEL_BOXES{ $folder }
        if defined $Zostay::Mail::LABEL_BOXES{ $folder };

    $folder =~ s{/}{.}g;

    my $orig = $self->file_name;

    my $dest = join '/', $Zostay::Mail::MAILDIR, $folder, $self->rd;
    unless (-d $dest) {
        warn "Folder $folder does not exist.";
        return;
    }

    my $new_file = join '/', $dest, $self->basename;
    rename $orig, $new_file
        or die sprintf "error move $orig to $new_file: $!";

    $self->file_name($new_file);
    $self->file_parts->[0] = $folder; # probably not necessary
    $self->folder($folder);
}

# Technically, you should never save a Maildir file directly. Instead, you
# create a file in ~/Mail/folder/tmp, write the file, and then rename the file
# into ~/Mail/folder/new. This means that a correct save requires that
# we create a completely new file with a completely unique name and unlink the
# old one. That's a pain. So, as an alternative, I move the file over to tmp,
# modify the file, and then move it back to ~/new or ~/cur, wherever it was
# before. Hopefully that doesn't break anything.
sub save {
    my $self = shift;

    my $tmp = join '/', $Zostay::Mail::MAILDIR, $self->folder, 'tmp', $self->basename;

    rename $self->file_name, $tmp
        or die sprintf "cannot move %s to %s: %s", $self->file_name, $tmp, $!;

    open my $out_fh, '>', $tmp
        or die sprintf "cannot update %s: %s", $tmp, $!;
    print $out_fh $self->mime->as_string;
    close $out_fh;

    rename $tmp, $self->file_name
        or die sprintf "cannot move %s to 5s: %s", $tmp, $self->file_name, $!;
}

sub best_alternate_folder {
    my $self = shift;

    my @keywords = $self->keywords;

    return 'JunkSocial' if $keywords[0] =~ /Social/;

    return $keywords[0] if @keywords;
    return 'gmail.All_Mail';
}

1;

# vim: ts=4 sts=4 sw=4
