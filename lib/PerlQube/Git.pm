package PerlQube::Git;

use strict;
use warnings;

use English qw( -no_match_vars );
use IPC::Cmd;
use IPC::Run3;
use List::Util qw( any );

use PerlQube::Exception;

sub new {
    my ( $class, $ref, $base ) = @_;

    if (!$ref || !$base) {
        PerlQube::Exception::Argument->throw('Invalid git reference.');
    }

    unless (IPC::Cmd::can_run('git')) {
        PerlQube::Exception::Command->throw('Git is not installed');
    }

    return bless {
        ref => $ref,
        base => $base,
    }, $class;
}

sub get_modified_files {
    my ( $self ) = @_;

    my @files;
    my $all_files = $self->get_files_status;
    while (my ($key, $value) = each %{ $all_files } ) {
        if ($value ne 'D') {
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

    unless ( $self->{_cache_blame_file} eq $file ) {
        $self->{_cache_blame_file} = $file;
        $self->{_blame} = $self->_blame($file);
    }

    return any { $_ eq $line } @{ $self->{_blame} };
}

sub _blame {
    my ( $self, $file ) = @_;

    my ( @stdout, @stderr );
    my $cmd = [ 'git', 'blame', '-s', '-C', "$self->{ref}..$self->{base}", '--', $file ];

    IPC::Run3::run3($cmd, undef, \@stdout, \@stderr);

    if ($? >> 8) {
        PerlQube::Exception::Git->throw(qq{Cannot blame file: @stderr});
    }

    return join(q{}, @stdout) =~ m/^[0-9a-f]+\s+(\d+)\)/xmsg;
}

1;
