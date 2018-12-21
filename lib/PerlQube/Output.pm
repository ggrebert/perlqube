package PerlQube::Output;

use strict;
use warnings;

use PerlQube::Exception;

sub process {
    PerlQube::Exception::UnsupportedOperation->throw('This method must be inherited.');
}

1;
