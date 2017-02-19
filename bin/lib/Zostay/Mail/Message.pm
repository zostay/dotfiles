package Zostay::Mail::Message;
use v5.24;
use warnings;
use Moo;

use DDP;
use DateTime;
use Date::Parse qw( str2time );
use Email::Address;
use Email::MIME;
use List::Util qw( all none );
use Try::Tiny;

has file_name => ( is => 'rw' );
has file_parts => ( is => 'ro', lazy => 1, builder => '_build_file_parts' );
has folder => ( is => 'rw', lazy => 1, builder => '_build_folder' );
has rd => ( is => 'ro', lazy => 1, builder => '_build_rd' );
has basename => ( is => 'ro', lazy => 1, builder => '_build_basename' );

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

sub _build__from {
    my $self = shift;
    [ Email::Address->parse($self->mime->header_str('From')) ]
}

sub _build__to {
    my $self = shift;
    [ Email::Address->parse($self->mime->header_str('To')) ]
}

sub from { @{ shift->_from } }
sub to { @{ shift->_to } }

sub apply_rule {
    my ($self, $c) = @_;

    my @actions;

    # Safeguard to prevent rules with no tests from affecting all
    my $tests = 0;

    # No need to try and set the label again
    return if defined $c->{label} && $self->has_keyword($c->{label});

    # No need to try and clear when already clear
    return if defined $c->{clear} && $self->missing_keyword($c->{clear});

    # No need to try and move when it's already here
    return if defined $c->{move} && $self->folder eq $c->{move};

    if (defined $c->{okay_date}) {
        $tests++;
        my $okay_date = $c->{okay_date};
        return unless DateTime->compare($self->date, $okay_date) < 0;
    }

    # Don't apply \Trash to important
    if (defined $c->{label} && $c->{label} eq '\Trash') {
        return if $self->has_keyword('\Important');
    }

    # Don't do anything if starred
    return if $self->has_keyword('\Starred');

    # Match From address, exact
    if (defined $c->{from}) {
        $tests++;
        return unless $self->from;

        return if none { $_->address eq $c->{from} } $self->from;
    }

    # Match From address, just the domain name
    if (defined $c->{from_domain}) {
        $tests++;
        return unless $self->from;
        return if none { $_->address =~ /@\Q$c->{from_domain}\E$/i } $self->from;
    }

    # Match To address, exact
    if (defined $c->{to}) {
        $tests++;
        return unless $self->to;

        return if none { $_->address eq $c->{to} } $self->to;
    }

    # Match To address, just the domain name
    if (defined $c->{to_domain}) {
        $tests++;
        return unless $self->to;

        return if none { $_->address =~ /@\Q$c->{to_domain}\E$/ } $self->to;
    }

    # Match by Subject, exact
    if (defined $c->{subject}) {
        $tests++;
        my $subject = $self->mime->header_str('Subject');
        return unless $c->{subject} eq $subject;
    }

    # Match by Subject, case-insensitive (with folded case)
    if (defined $c->{isubject}) {
        $tests++;
        my $subject = $self->mime->header_str('Subject');
        return unless fc $c->{isubject} eq fc $subject;
    }

    # Match by Subject, anywhere in subject
    if (defined $c->{subject_contains}) {
        $tests++;
        my $subject = $self->mime->header_str('Subject');
        return unless $subject =~ /\Q$c->{subject_contains}\E/;
    }

    # Match by Subject, anywhere in subject, case insensitive
    if (defined $c->{subject_icontains}) {
        $tests++;
        my $subject = $self->mime->header_str('Subject');
        return unless $subject =~ /\Q$c->{subject_icontains}\E/i;
    }

    # Match word string, anywhere in message, exact
    if (defined $c->{contains}) {
        $tests++;
        return unless $self->text =~ /\b\Q$c->{contains}\E\b/;
    }

    # Match word string, anywhere in message, case insensitive
    if (defined $c->{icontains}) {
        $tests++;
        return unless $self->text =~ /\b\Q$c->{icontains}\E\b/i;
    }

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
        p $c->{clear};
        $self->remove_keyword($c->{clear});
        if (ref $c->{clear}) {
            push @actions, "Cleared $_" for @{ $c->{clear} };
        }
        else {
            push @actions, "Cleared $c->{clear}";
        }

    }

    # Write the message back with changes
    if (@actions) {
        $self->save;
    }

    # Move to a different folder
    if (defined $c->{move}) {
        $self->move_to($c->{move});
        push @actions, "Moved $c->{move}";
    }

    return @actions;
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

    my $keywords = $self->mime->header_str('Keywords');
    my @keywords = $keywords ? split(/[\s,]+/, $keywords) : ();

    return $keywords[0] if @keywords;
    return 'gmail.All_Mail';
}

1;
