package PerlQube::Output;

use strict;
use warnings;

use Readonly;

use PerlQube::Exception;

Readonly my @SEVERITIES => qw(
    info
    minor
    major
    critical
    blocker
);

sub new {
    my ( $class, $config ) = @_;

    return bless { config => $config }, $class;
}

sub process {
    PerlQube::Exception::UnsupportedOperation->throw('This method must be inherited.');
}

sub severity_to_str {
    my ( $self, $level ) = @_;

    return $SEVERITIES[$level];
}

1;
