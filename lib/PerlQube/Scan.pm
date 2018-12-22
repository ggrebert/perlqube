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

    foreach my $file (@files) {
        my @file_violations = $self->{config}->{perlcritic}->critique($file);

        if ($self->{config}->{git}) {
            @file_violations = $self->{config}->{git}->filter(@file_violations);
        }

        push @violations, @file_violations;
    }

    foreach my $violation (@violations) {
        print $violation;
    }

    return wantarray ? @violations : \@violations;
}

1;
