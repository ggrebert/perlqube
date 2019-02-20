package PerlQube::Output::Html;

use strict;
use warnings;

use base qw( PerlQube::Output );

use PerlQube::Output::Html::Bootstrap4;
use PerlQube::Output::Html::OnePageBootstrap4;
sub new {
    my ( $class, @params ) = @_;

    return PerlQube::Output::Html::OnePageBootstrap4->new(@params);
}

1;
