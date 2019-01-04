package PerlQube::Git;

use strict;
use warnings;

use English qw( -no_match_vars );
use IPC::Cmd;
use IPC::Run3;
use List::Util qw( any );

use PerlQube::Exception;

sub new {
    my ( $class, $ref, $base, $config ) = @_;

    unless (IPC::Cmd::can_run('git')) {
        PerlQube::Exception::Command->throw('Git is not installed');
    }

    my $self = bless { config => $config }, $class;

    $self->{ref} = $self->_init_ref($ref);
    $self->{base} = $self->_init_base($base);

    return $self;
}

sub get_modified_files {
    my ( $self ) = @_;

    my @files;
    my $all_files = $self->get_files_status;
    while (my ($key, $value) = each %{ $all_files } ) {
        if ($value ne 'D' && $key =~ m/\.p[lm]$/xms) {
            push @files, $key;
        }
    }

    return @files;
}

sub get_files_status {
    my ( $self ) = @_;

    unless (defined $self->{_files_status}) {
        $self->{_files_status} = {};

        my ( @stdout, @stderr );
        my $cmd = [ 'git', 'diff', '--name-status', $self->{ref}, $self->{base} ];

        IPC::Run3::run3($cmd, undef, \@stdout, \@stderr);

        if ($? >> 8) {
            PerlQube::Exception::Git->throw(qq{Cannot get files status: @stderr});
        }

        foreach my $row (@stdout) {
            my ( $status, $file ) = $row =~ m/^(\w)\s+([^\n]+)/xms;

            $self->{_files_status}->{$file} = $status;
        }
    }

    return $self->{_files_status};
}

sub get_file_status {
    my ( $self, $file ) = @_;

    return $self->get_files_status()->{$file};
}

sub is_new_file {
    my ( $self, $file ) = @_;

    return $self->get_file_status($file) eq 'A' ? 1 : 0;
}

sub is_modified_file {
    my ( $self, $file ) = @_;

    return $self->get_file_status($file) eq 'M' ? 1 : 0;
}

sub is_modified_line {
    my ( $self, $file, $line ) = @_;

    if ( !$self->{_cache_blame_file} || $self->{_cache_blame_file} ne $file ) {
        $self->{_cache_blame_file} = $file;
        my @blame = $self->_blame($file);
        $self->{_blame} = \@blame;
    }

    return any { $_ eq $line } @{ $self->{_blame} };
}

sub filter {
    my ( $self, @violations ) = @_;

    $self->{config}->{gitlab}->get_last_scan;
    return map { $self->is_new_violation($_) ? $_ : () } @violations;
}

sub is_new_violation {
    my ( $self, $violation ) = @_;

    if ($self->is_new_file($violation->filename)) {
        return 1;
    }

    if (!$violation->line_number) {
        # check if is a new violation
        return !$self->is_already_exists($violation);
    }

    if ($self->is_modified_line($violation->filename, $violation->line_number)) {
        return 1;
    }

    return 0;
}

sub is_already_exists {
    my ( $self, $violation ) = @_;

    my $currents = $self->{config}->{gitlab}->get_last_scan;
    foreach my $current (@{ $currents->{violations} }) {
        if ( $violation->filename ne $current->{filename} ) {
            next;
        }

        if ( $violation->source ne $current->{source} ) {
            next;
        }

        if ( $violation->policy ne $current->{policy} ) {
            next;
        }

        if ( $violation->line_number == $current->{line} ) {
            return 1;
        }
    }

    return 0;
}

sub _blame {
    my ( $self, $file ) = @_;

    my ( @stdout, @stderr );
    my $cmd = [ 'git', 'blame', '-s', '-C', "origin/$self->{base}..$self->{ref}", '--', $file ];

    IPC::Run3::run3($cmd, undef, \@stdout, \@stderr);

    if ($? >> 8) {
        PerlQube::Exception::Git->throw(qq{Cannot blame file: @stderr});
    }

    return join(q{}, @stdout) =~ m/^[0-9a-f]+\s+(\d+)\)/xmsg;
}

sub _init_ref {
    my ( $self, $ref ) = @_;

    $ref = $ref || $ENV{CI_COMMIT_SHA};

    if ( $ref !~ m/^\b[0-9a-f]{5,40}\b$/xms ) {
        PerlQube::Exception::Argument->throw('Invalid git reference.');
    }

    return $ref
}

sub _init_base {
    my ( $self, $base ) = @_;

    $base = $base || $ENV{CI_MERGE_REQUEST_TARGET_BRANCH_NAME};

    if ( $base !~ m/^[\w\/]+$/xms ) {
        PerlQube::Exception::Argument->throw('Invalid git branch name.');
    }

    return $base;
}

1;
