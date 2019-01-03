package PerlQube::Output::Html::Bootstrap4;

use strict;
use warnings;

use base qw( PerlQube::Output::Html::Base );

sub get_template_namespace {
    return 'Bootstrap4';
}

sub template {
    my ( $self ) = @_;

    my $html_links = {
        files => {}
    };

    foreach my $file (keys %{ $self->{files} }) {
        my $html_file = $self->tpl_file($file);

        $html_links->{files}->{$file} = $html_file;
    }

    $self->tpl_index($html_links);
}

1;
