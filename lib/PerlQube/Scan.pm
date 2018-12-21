package PerlQube::Scan;

use strict;
use warnings;

use English qw( -no_match_vars );
use IPC::Run3;
use Perl::Critic;
use Perl::Critic::Utils;
use Pod::Usage;
use List::Util;

use PerlQube::Exception;

sub new {
    my ( $class, $config ) = @_;

    my $self = bless {
        config => $config
    }, $class;

    return $self;
}

sub scan {
    my ( $self ) = shift;

    my @files = @{ $self->{config}->{files} };
    my @violations;

    if (@files) {
        @violations = $self->{config}->{perlcritic}->critique(@files);

        foreach my $violation (@violations) {
            #$violation->{new} = $self->_is_new(@violations);
            print $violation;
        }
    }

    return wantarray ? @violations : \@violations;
}

sub _get_files {
    my ( $self ) = @_;

    # On GIT environment, return only the list of modified files.
    if ($self->{preview}) {
        return $self->{_git}->get_modified_files();
    }

    my @files = @{ $self->{configs}->{inputs} };

    # Test to make sure all the specified files or directories
    # actually exist.  If any one of them is bogus, then die.
    if ( my $nonexistent = List::Util::first { !-e } @files ) {
        PerlQube::Exception::FileNotFound->throw(qq{No such file or directory: '$nonexistent'});
    }

    # Reading code from files or dirs.  If argument is a file,
    # then we process it as-is (even though it may not actually
    # be Perl code).  If argument is a directory, recursively
    # search the directory for files that look like Perl code.
    return map { (-d) ? Perl::Critic::Utils::all_perl_files($_) : $_ } @files;
}

sub _get_git_files_status {
    my ( $self ) = @_;

    unless ($self->{_git_files_status}) {
        my ( @stdout, @stderr );

        my $cmd = [ 'git', 'diff', '--name-status', $self->{_git_origin_ref}, $self->{_git_current_ref} ];

        IPC::Run3::run3($cmd, undef, \@stdout, \@stderr);

        my $exit_code = $? >> 8;

        if ($exit_code) {
            PerlQube::Exception::Git->throw(qq{Cannot get files status: @stderr});
        }

        print "result: @stdout";
    }

    return wantarray ? @{ $self->{_git_files_status} } : $self->{_git_files_status};
}

sub _get_git_file_status {
    my ( $self, $file ) = @_;

    return $self->_get_git_files_status()->{$file};
}

sub _is_new {
    my ( $self, $violation ) = @_;

    if ($self->_is_new_file($violation)) {
        return 1;
    }

    if (!$self->_is_modified_file($violation)) {
        return 0;
    }

    if ($violation->line()) {
        if ($self->_is_modified_line($violation)) {
            return 1;
        }
    }
    elsif (!$self->_is_violation_already_exists($violation)) {
        return 1;
    }

    return 0;
}

sub _is_new_file {
    my ( $self, $violation ) = @_;

    return $self->_get_git_file_status($violation->filename()) eq 'A' ? 1 : 0;
}

sub _is_modified_file {
    my ( $self, $violation ) = @_;

    return $self->_get_git_file_status($violation->filename()) eq 'M' ? 1 : 0;
}

sub _is_modified_line {
    my ( $self, $violation ) = @_;
}

1;
