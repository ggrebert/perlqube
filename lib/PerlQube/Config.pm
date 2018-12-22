package PerlQube::Config;

use strict;
use warnings;

use Perl::Critic;
use PerlQube::Exception;
use PerlQube::Git;
use PerlQube::GitLab;

sub new {
    my ( $class, $opts, @argv ) = @_;

    if (!$opts->{json}) {
        $opts->{json} = $ENV{PERLQUBE_JSON};
    }

    my $self = bless { opts => $opts }, $class;

    return $self->_init($opts, @argv);
}

sub _init {
    my ( $self, $opts, @argv ) = @_;

    $self->{debug} = $opts->{debug};

    my @files;

    if ( $opts->{preview} ) {
        # The preview mode use GIT
        # only modified files will be analyzed
        $self->{git} = PerlQube::Git->new(
            $opts->{git_ref},
            $opts->{git_ref_base},
            $self,
        );
        $self->{gitlab} = PerlQube::GitLab->new($opts, $self);

        @files = $self->{git}->get_modified_files();
    }
    else {
        @files = $self->_get_files(@argv);
    }

    $self->{files} = \@files;

    $self->{perlcritic} = Perl::Critic->new(
        -severity => $opts->{severity} || $ENV{PERLQUBE_SEVERITY},
        -profile  => $opts->{profile},
        -theme    => $opts->{theme},
    );

    $self->{outputs} = $self->_init_outputs($opts);

    return $self;
}

sub _get_files {
    my ( $self, @files ) = @_;

    if (!@files) {
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

1;
