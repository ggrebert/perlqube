package PerlQube::Exception;

use strict;
use warnings;

use Exception::Class (
    'PerlQube::Exception::Argument',
    'PerlQube::Exception::FileOpen',
    'PerlQube::Exception::FileNotFound',
    'PerlQube::Exception::Git',
    'PerlQube::Exception::Command',
    'PerlQube::Exception::UnsupportedOperation',
);

1;
