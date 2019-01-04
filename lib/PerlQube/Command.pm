package PerlQube::Command;

use strict;
use warnings;

use Config;
use English qw( -no_match_vars );
use Exception::Class;
use Exporter 'import';
use Getopt::Long;
use Pod::Usage;
use Readonly;
use Try::Tiny;

use PerlQube;

Readonly::Array our @EXPORT_OK => qw< run >;
Readonly::Hash our %EXPORT_TAGS => ( all => [ @EXPORT_OK ] );

Readonly::Scalar my $EXIT_SUCCESS => 0;
Readonly::Scalar my $EXIT_FAILURE => 1;

sub run {
    my $opts = {};

    Getopt::Long::GetOptions(
        'help|h|?'          => sub { help() },
        'version|v'         => sub { version() },
        'severity|s=s'      => \$opts->{severity},
        'profile|p=s'       => \$opts->{profile},
        'theme|t=s'         => \$opts->{theme},
        'json|j=s'          => \$opts->{json},
        'json-pretty'       => \$opts->{json_pretty},
        'html=s'            => \$opts->{html},
        'git-ref=s'         => \$opts->{git_ref},
        'git-ref-base=s'    => \$opts->{git_ref_base},
        'gitlab-token=s'    => \$opts->{gitlab_token},
        'gitlab-url=s'      => \$opts->{gitlab_url},
        'gitlab-id=s'       => \$opts->{gitlab_id},
        'preview'           => \$opts->{preview},
        'debug'             => \$opts->{debug},
    ) or Pod::Usage::pod2usage(
        -exitstatus => $EXIT_FAILURE,
        -message    => 'Error in command line arguments',
        -verbose    => 1
    );

    try {
        PerlQube->new($opts, @ARGV)->critique();
    }
    catch {
        say {*STDERR} "\n[ERROR] " . $ARG;

        return $EXIT_FAILURE;
    };

    return $EXIT_SUCCESS;
}

sub help { ## no critic qw(Subroutines::RequireFinalReturn)
    Pod::Usage::pod2usage(
        -verbose => 1,
        -exitval => $EXIT_SUCCESS,
    );
}

sub version {
    my @infos = (
        qq{VERSION:\t$PerlQube::VERSION},
        qq{PERL:\t\t$PERL_VERSION},
        qq{OS NAME:\t$Config{osname}},
        qq{OS ARCH:\t$Config{archname}},
    );

    for my $info (@infos) {
        say {*STDOUT} $info;
    }

    exit $EXIT_SUCCESS;
}

1;

__END__
