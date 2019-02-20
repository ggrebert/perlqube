package PerlQube::Output::Json;

use strict;
use warnings;

use DateTime;
use English qw( -no_match_vars );
use JSON;

use base qw( PerlQube::Output );

sub process {
    my ( $self, $data ) = @_;

    my $output = $self->get_json($data, $self->{config}->{opts}->{json_pretty});

    my $file = $self->{config}->{opts}->{json} || $ENV{PERLQUBE_JSON};

    open my $fh, '>:encoding(UTF-8)', $file or do {
        PerlQube::Exception::FileOpen->throw(
            qq{Could not open file '$self->{output}' $ERRNO}
        );
    };

    print {$fh} $output;

    close $fh;

    return $output;
}

sub get_json {
    my ( undef, $data, $pretty ) = @_;

    my $json = JSON->new->convert_blessed;

    if ( $pretty ) {
        $json->pretty;
    }

    my $output = {
        violations => $data->{violations},
        timestamp  => DateTime->now,
    };

    if ($data->{metrics}) {
        my @file_stats;
        my $subs = $data->{metrics}->subs;

        foreach my $file (@{ $data->{metrics}->file_stats }) {
            my @file_subs = grep { $_->{path} eq $file->{path} } @{$subs};

            my $file_metric = {
                path => $file->{path},
                lines => $file->{main_stats}->{lines},
                mccabe_complexity => $file->{main_stats}->{mccabe_complexity},
                subs => \@file_subs,
            };

            push @file_stats, $file_metric;
        }

        $output->{metrics} = {
            file_count => $data->{metrics}->file_count,
            package_count => $data->{metrics}->package_count,
            package_count => $data->{metrics}->package_count,
            sub_count => $data->{metrics}->sub_count,
            lines => $data->{metrics}->lines,
            main_stats => $data->{metrics}->main_stats,
            file_stats => \@file_stats,
        };
    }

    if ( $data->{analyzer} ) {
        $output->{analyzer} = $data->{analyzer};
    }

    return $json->encode($output);
}

1;
