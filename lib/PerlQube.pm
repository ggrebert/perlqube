package PerlQube;

use strict;
use warnings;

use PerlQube::Config;
use PerlQube::Scan;

## no critic (Perl::Critic::Policy::ValuesAndExpressions::RequireInterpolationOfMetachars)
our $VERSION = '@@PROJECT_VERSION@@';

sub new {
    my ( $class, $options, @argv ) = @_;

    return bless { config => PerlQube::Config->new( $options, @argv ) }, $class;
}

sub critique {
    my ($self) = @_;

    my $scanner    = PerlQube::Scan->new( $self->{config} );
    my @violations = $scanner->scan();

    foreach my $output ( @{ $self->{config}->{outputs} } ) {
        $output->process(@violations);
    }

    return 1;
}

1;
