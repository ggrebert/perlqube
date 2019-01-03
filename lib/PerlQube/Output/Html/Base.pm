package PerlQube::Output::Html::Base;

use strict;
use warnings;

use File::Path;
use File::Spec;
use File::ShareDir;
use Template;
use Text::Unidecode;
use Unicode::Normalize;

use PerlQube::Exception;

use base qw( PerlQube::Output );

sub new {
    my ( $class, @params ) = @_;

    my $self = $class->SUPER::new(@params);
    $self->{output} = $self->{config}->{opts}->{html};

    if ( -d $self->{output} ) {
        PerlQube::Exception::FileOpen->throw('HTML output directory already exists');
    }

    File::Path::make_path $self->{output} or do {
        PerlQube::Exception::FileOpen->throw('Error while creating directory');
    };

    return $self;
}

sub get_template_namespace {
    PerlQube::Exception::UnsupportedOperation->throw('This method must be inherited.');
}

sub process {
    my ( $self, $data ) = @_;

    my %files;
    my %severities;

    foreach my $violation (@{$data->{violations}}) {
        if ( !exists $files{$violation->filename} ) {
            $files{$violation->filename} = [];
        }

        if ( !exists $severities{$violation->severity} ) {
            $severities{$violation->severity} = [];
        }

        push @{ $files{$violation->filename} }, $violation;
        push @{ $severities{$violation->severity} }, $violation;
    }

    $self->{metrics} = $data->{metrics};
    $self->{analyzer} = $data->{analyzer};
    $self->{violations} = $data->{violations};

    $self->{files} = \%files;
    $self->{severities} = \%severities;
    $self->{file_stats} = $data->{metrics}->file_stats;
    $self->{subs} = $data->{metrics}->subs;

    return $self->template;
}

sub tpl_process {
    my ( $self, $input, $vars, $output ) = @_;

    my $error = 0;
    my $directory = File::ShareDir::module_dir('PerlQube');
    my $namespace = $self->get_template_namespace();

    my $template = Template->new({
        INCLUDE_PATH => "${directory}/${namespace}",
        ENCODING     => 'utf8',
        STRICT       => 0,
    });

    $template->process($input, $vars, "$self->{output}/$output") or do {
        warn $template->error;
        $error = 1;
    };

    return !$error;
}

sub tpl_file {
    my ( $self, $filename ) = @_;

    my @subs = grep { $_->{path} eq $filename } @{ $self->{subs} };
    my @violations = sort { $b->severity() <=> $a->severity() } @{ $self->{files}->{$filename} };

    my $metrics;
    foreach my $file (@{ $self->{file_stats} }) {
        if ( $file->{path} eq $filename ) {
            $metrics = $file->{main_stats};
            $metrics->{violation_count} = scalar @violations;
            $metrics->{mccabe_complexity_total} = $metrics->{mccabe_complexity};

            foreach my $sub (@subs) {
                $metrics->{lines} += $sub->{lines};
                $metrics->{mccabe_complexity_total} += $sub->{mccabe_complexity};
            }

            last;
        }
    }

    my $vars = {
        filename => $filename,
        analyzer => $self->{analyzer}->{$filename},
        violations => \@violations,
        subs => \@subs,
        metrics => $metrics,
        self => $self,
    };

    my $slug = $self->slugify($filename);

    my $output = "files/$slug.html";

    $self->tpl_process('file.html', $vars, $output);

    return $output;
}

sub tpl_index {
    my ( $self, $links ) = @_;

    my $vars = {
        metrics => $self->{metrics},
        analyzer => $self->{analyzer},
        violations => $self->{violations},
        files => $self->{files},
        severities => $self->{severities},
        file_stats => $self->{file_stats},
        subs => $self->{subs},
        links => $links,
        self => $self,
    };

    $self->tpl_process('index.html', $vars, 'index.html');
}

sub get_file_metrics {
    my ( $self, $filename ) = @_;

    foreach my $file (@{ $self->{file_stats} }) {
        if ( $file->{path} eq $filename ) {
            my $metrics = $file->{main_stats};

            my @subs = grep { $_->{path} eq $filename } @{ $self->{subs} };
            $metrics->{sub_count} = scalar @subs;

            foreach my $sub (@subs) {
                $metrics->{lines} += $sub->{lines};
            }

            return $metrics;
        }
    }
}

sub slugify {
    my ( $self, $input ) = @_;

    $input = NFC($input);           # Normalize (recompose) the Unicode string
    $input = unidecode($input);     # Convert non-ASCII characters to closest equivalents
    $input =~ s/\.\w+$//xms;        # Remove file extantion
    $input =~ s/[^\w\s-]/-/xmsg;    # Remove all characters that are not word characters (includes _), spaces, or hyphens
    $input =~ s/^\s+|\s+$/-/xmsg;   # Trim whitespace from both ends
    $input = lc $input;             # lower case
    $input =~ s/[-\s]+/-/xmsg;      # Replace all occurrences of spaces and hyphens with a single hyphen

    return $input;
}

sub diagnostics_to_html {
    my ( $self, $content ) = @_;

    $content =~ s/^[ ]{4}//xmsg;

    my $html = q{};
    my $in_script = 0;
    my $in_paragraph = 0;

    foreach my $row (split /\n/, $content ) {
        if ($row =~ m/^[ ]{2}/xms) {
            $row =~ s/^[ ]{2}//xms;

            if (!$in_script) {
                if ($in_paragraph) {
                    $html .= '</p>';
                }

                $html .= '<pre><code class="perl">';
                $in_script = 1;
            }
        }
        elsif ($row) {
            if ($in_script) {
                $html .= '</code></pre>';
                $in_script = 0;
            }

            if (!$in_paragraph) {
                $html .= '<p>';
                $in_paragraph = 1;
            }

            $row =~ s/`'([^']+)''/<code>$1<\/code>/xmsg;
            $row =~ s/`([^'])'/<code>$1<\/code>/xmsg;

            # find Perl package
            $row =~ s/(\w+::\w+[\w:]+)+/<code>$1<\/code>/xmsg;
        }
        elsif (!$in_script) {
            $html .= $in_paragraph ? '</p>' : '<p>';
            $in_paragraph = !$in_paragraph;
        }

        $html .= "$row\n";
    }

    if ($in_script) {
        $html .= '</code></pre>';
    }

    if ($in_paragraph) {
        $html .= '</p>';
    }

    return $html;
}

1;
