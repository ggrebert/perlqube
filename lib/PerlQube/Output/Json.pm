package PerlQube::Output::Json;

use strict;
use warnings;

use JSON;

use base qw( PerlQube::Output );

sub new {
    my ( $class, $output, %options ) = @_;

    my $self = bless {
        output => $output,
        options => \%options,
    }, $class;

    return $self;
}

sub Perl::Critic::Violation::TO_JSON {
    my ( $violation ) = @_;

    return {
        filename    => $violation->{_filename},
        line        => $violation->line_number(),
        column      => $violation->column_number(),
        explanation => $violation->{_explanation},
        severity    => $violation->severity(),
        source      => $violation->{_source},
        policy      => $violation->policy(),
        description => $violation->description(),
        diagnostics => $violation->diagnostics(),
    };
}

sub process {
    my ( $self, @violations ) = @_;

    my $json = JSON->new->convert_blessed;

    if ( $self->{options}->{pretty} ) {
        $json->pretty;
    }

    my $output = $json->encode( \@violations );

    open my $fh, '>:encoding(UTF-8)', $self->{output}
        or PerlQube::Exception::FileOpen->throw(
            qq{Could not open file '$self->{output}' $!}
        );

    print $fh $output;

    close $fh;

    return $output;
}

1;
