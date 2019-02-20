package PerlQube::Output::Html::OnePageBootstrap4;

use strict;
use warnings;

use base qw( PerlQube::Output::Html::Base );

sub get_template_namespace {
    return 'OnePageBootstrap4';
}

sub process {
    my ( $self, $data ) = @_;

    $self->{json} = PerlQube::Output::Json->get_json( $data );

    return $self->SUPER::process($data);
}

sub template {
    my ( $self ) = @_;

    $self->tpl_index();
}

sub get_index_vars {
    my ( $self ) = @_;

    return { json => $self->{json} };
}

1;
