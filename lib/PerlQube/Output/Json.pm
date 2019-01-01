package PerlQube::Output::Json;

use strict;
use warnings;

use DateTime;
use DateTime::Format::RFC3339;
use DateTimeX::TO_JSON formatter => 'DateTime::Format::RFC3339';
use JSON;

use base qw( PerlQube::Output );

sub new {
    my ( $class, $output, $options ) = @_;

    my $self = bless {
        output => $output,
        options => $options,
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
    my ( $self, $data ) = @_;

    my $json = JSON->new->convert_blessed;

    if ( $self->{options}->{pretty} ) {
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
                violation_count => scalar(
                    grep {  }
                )
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

    $output = $json->encode($output);

    open my $fh, '>:encoding(UTF-8)', $self->{output}
        or PerlQube::Exception::FileOpen->throw(
            qq{Could not open file '$self->{output}' $!}
        );

    print $fh $output;

    close $fh;

    return $output;
}

1;
