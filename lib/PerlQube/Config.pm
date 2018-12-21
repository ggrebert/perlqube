package PerlQube::Config;

use strict;
use warnings;

use Perl::Critic;
use PerlQube::Exception;

our $VERSION = '@@PROJECT_VERSION@@';

sub new {
    my ( $class, $opts, @argv ) = @_;

    my $self = bless { }, $class;

    return $self->_init($opts, @argv);
}

sub _init {
    my ( $self, $opts, @argv ) = @_;

    $self->{debug} = $opts->{debug};

    my @files;

    if ( $opts->{preview} ) {
        # The preview mode use GIT
        # only modified files will be analyzed
        $self->{git} = $self->_init_git($opts);
        @files = $self->{git}->get_modified_files();
    }
    else {
        @files = $self->_get_files(@argv);
    }

    $self->{files} = \@files;

    $self->{perlcritic} = Perl::Critic->new(
        -severity => $opts->{severity},
        -profile  => $opts->{profile},
        -theme    => $opts->{theme},
    );

    $self->{outputs} = $self->_init_outputs($opts);

    return $self;
}

sub _validate_git_ref {
    my ( $self, $commit ) = @_;

    return $self->_validate_commit($commit || $ENV{CI_COMMIT_SHA});
}

sub _validate_git_ref_base {
    my ( $self, $commit ) = @_;

    return $self->_validate_commit($commit || $ENV{CI_COMMIT_BEFORE_SHA});
}

sub _validate_commit {
    my ( $self, $commit ) = @_;

    if ( $commit !~ m/^[0-9a-f]+$/xms ) {
        PerlQube::Exception::Argument->throw('Invalid commit reference.');
    }

    return $commit;
}

sub _get_files {
    my ( $self, @files ) = @_;

    unless (@files) {
        PerlQube::Exception::Argument->throw('No file pass to argument.');
    }

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

sub _init_outputs {
    my ( $self, $opts ) = @_;

    my @outputs;

    if ( $opts->{json} ) {
        require PerlQube::Output::Json;

        push @outputs, PerlQube::Output::Json->new($opts->{json},
            pretty => $opts->{json_pretty},
        );
    }

    return \@outputs;
}

sub _init_git {
    my ( $self, $opts ) = @_;

    require PerlQube::Git;

    return PerlQube::Git->new(
        $opts->{git_ref},
        $opts->{git_ref_base}
    );
}

1;
