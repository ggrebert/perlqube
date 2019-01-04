package PerlQube::Output::GitLab;

use strict;
use warnings;

use File::ShareDir;
use Template;

use base 'PerlQube::Output';

sub process {
    my ( $self, $data ) = @_;

    my $directory = File::ShareDir::module_dir('PerlQube');

    my $template = Template->new({
        INCLUDE_PATH => "${directory}/GitLab",
        ENCODING     => 'utf8',
        STRICT       => 0,
    });

    foreach my $violation ( @{$data->{violations}} ) {
        my $vars = {
            violation => $violation,
            self => $self,
        };

        my $comment = q{};
        $template->process('note.md', $vars, \$comment) or do {
            warn $template->error;
        };

        $self->{config}->{gitlab}->post_commit_comment(
            $comment,
            $violation->filename,
            $violation->line_number,
            'new'
        );
    }
}

sub str_to_markdown {
    my ( $self, $content ) = @_;

    $content =~ s/^[ ]{4}//xmsg;

    my $markdown = q{};
    my $in_script = 0;

    foreach my $row (split /\n/, $content ) {
        if ($row =~ m/^[ ]{2}/xms) {
            $row =~ s/^[ ]{2}//xms;

            if (!$in_script) {
                $markdown .= "```perl\n";
                $in_script = 1;
            }
        }
        elsif ($row) {
            if ($in_script) {
                $markdown .= "```\n\n";
                $in_script = 0;
            }

            $row =~ s/`'([^']+)''/`$1`/xmsg;
            $row =~ s/`([^']+)'/`$1`/xmsg;

            # find Perl package
            $row =~ s/(\w+::\w+[\w:]+)+/`$1`/xmsg;
        }

        $markdown .= "$row\n";
    }

    if ($in_script) {
        $markdown .= "```\n\n";
    }

    return $markdown;
}

1;
