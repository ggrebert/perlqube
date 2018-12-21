package PerlQube::Output::GitLab;

use strict;
use warnings;

use base 'PerlQube::Output';

sub process {
    my ( $self ) = @_;
}

sub _to_markdown {
    my ( $self, $content ) = @_;

    $content =~ s/^[ ]{4}//xmsg;

    my $markdown = q{};
    my $inScript = 0;

    foreach my $row (split /\n/, $content ) {
        if ($row =~ m/^[ ]{2}/xms) {
            $row =~ s/^[ ]{2}//xms;

            if (!$inScript) {
                $markdown .= "```perl\n";
                $inScript = 1;
            }
        }
        elsif ($row) {
            if ($inScript) {
                $markdown .= "```\n\n";
                $inScript = 0;
            }

            $row =~ s/`([^']+)'/`$1`/xmsg;
            $row =~ s/'([^'])'/`$1`/xmsg;
        }

        $markdown .= "$row\n";
    }

    if ($inScript) {
        $markdown .= "```\n\n";
    }

    return $markdown;
}

1;
