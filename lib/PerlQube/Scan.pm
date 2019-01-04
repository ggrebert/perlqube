package PerlQube::Scan;

use strict;
use warnings;

use English qw( -no_match_vars );
use IPC::Run3;
use Module::ScanDeps;
use Perl::Critic;
use Perl::Critic::Utils;
use Perl::Metrics::Simple;
use Pod::Usage;
use List::Util;
use Safe;

use PerlQube::Exception;

sub new {
    my ( $class, $config ) = @_;

    my $self = bless {
        config => $config
    }, $class;

    return $self;
}

sub scan {
    my ( $self ) = shift;

    my @violations = $self->perlcritic();
    my $data = { violations => \@violations };

    if (!$self->{config}->{opts}->{preview}) {
        $data->{metrics}  = $self->metrics();
        $data->{analyzer} = $self->analyzer();
    }

    return $data;
}

sub perlcritic {
    my ( $self ) = shift;

    my @files = @{ $self->{config}->{files} };
    my @violations;

    foreach my $file (@files) {
        my @file_violations = $self->{config}->{perlcritic}->critique($file);

        if ($self->{config}->{git}) {
            @file_violations = $self->{config}->{git}->filter(@file_violations);
        }

        if (@file_violations) {
            say STDOUT $file;

            foreach my $violation (@file_violations) {
                print STDOUT "\t$violation";
            }

            push @violations, @file_violations;
        }
    }

    return wantarray ? @violations : \@violations;
}

sub metrics {
    my ( $self ) = shift;

    my @files = @{ $self->{config}->{files} };

    my $analyzer = Perl::Metrics::Simple->new;

    return $analyzer->analyze_files(@files);
}

sub analyzer {
    my ( $self ) = @_;

    my @files = @{ $self->{config}->{files} };
    my $analyzer = {};

    foreach my $file (@files) {
        open my $fh, '<', $file or do {
            warn("Can't open file $file for read: $!");
        };

        $self->{_analyser} = {
            dependencies => [],
            inheritance => [],
            call => {},
        };

        $self->{_in_pod} = 0;

        while (<$fh>) {
            my $line = $_;

            $line =~ s/\r?\n$//xms;

            if ( $line =~ m/^=\w+/xms && $line !~ m/^=cut/xms ) {
                $self->{_in_pod} = 1;
            }

            if ( $self->{_in_pod} ) {
                if ( $line =~ m/^=cut/xms ) {
                    $self->{_in_pod} = 0;
                }

                next;
            }

            if ( $line =~ m/^\s*__(END|DATA)__/xms ) {
                last;
            }

            # skip lines which are not belong to package namespace
            if ( !$self->{_analyser}->{package} ) {
                $self->{_analyser}->{package} = $self->_parse_package($line);
                next;
            }

            push @{ $self->{_analyser}->{dependencies} }, $self->_parse_dependencies($line);

            push @{ $self->{_analyser}->{inheritance} }, $self->_parse_inheritance($line, $fh);

            # call method of another package
            $self->_parse_method_call($line);
        }

        close $fh;

        $analyzer->{$file} = $self->{_analyser};
    }

    foreach my $analyze (values %{ $analyzer }) {
        my @children = $self->_find_children( $analyzer, $analyze->{package} );

        foreach my $dependency (@{ $analyze->{dependencies} }) {
            push @children, {
                name => $dependency,
                type => 'dependency',
            };
        }

        my $mdata = {
            name => $analyze->{package},
            type => 'pkg-current',
            children => \@children,
            parents => $self->_find_parents($analyzer, $analyze->{package}, $analyze->{inheritance}),
        };

        $analyze->{tree} = $mdata;
    }

    return $analyzer;
}

sub _find_parents {
    my ( $self, $analyzer, $package, $inheritance ) = @_;

    my @data;
    foreach my $parent (@{ $inheritance }) {
        foreach my $analyze (values %{ $analyzer }) {
            if ( $analyze->{package} ne $parent ) {
                next;
            }

            my @dependencies;
            foreach my $dependency (@{ $analyze->{dependencies} }) {
                push @dependencies, {
                    name => $dependency,
                    type => 'dependency',
                };
            }

            push @data, {
                type => 'pkg-parent',
                name => $analyze->{package},
                children => \@dependencies,
                parents => $self->_find_parents($analyzer, $analyze->{package}, $analyze->{inheritance}),
            };

            last;
        }
    }

    return \@data;
}

sub _find_children {
    my ( $self, $analyzer, $package ) = @_;

    my @data;
    foreach my $analyze (values %{ $analyzer }) {
        if ( scalar @{ $analyze->{inheritance} } && grep /^$package$/, @{ $analyze->{inheritance} } ) {
            my @children = $self->_find_children( $analyzer, $analyze->{package} );

            push @data, {
                name => $analyze->{package},
                type => 'pkg-child',
                children => \@children,
            };
        }
    }

    return @data;
}

sub _parse_package {
    my ( $self, $line ) = @_;

    if ( $line =~ m/^\s*package\s+([\w\:]+)\s*;/ ) {
        return $1
    }
}

sub _parse_dependencies {
    my ( $self, $line ) = @_;

    my @dependencies;

    if ( $line =~ m/^\s*use\s+([\w\:]+)/xms ) {
        if ( $1 !~ m/^(?:strict|warnings|base|parent|5[.].*)$/xms ) {
            push @dependencies, $1;
        }
    }
    elsif ( $line =~ m/^\s*require\s+([^\s;]+)/xms ) {
        my $required = $1;

        $required =~ s/['"]//xmsg;
        $required =~ s/\//::/xmsg;
        $required =~ s/[.]\w+$//xmsg;

        push @dependencies, $required;
    }

    return @dependencies;
}

sub _parse_inheritance {
    my ( $self, $line, $fh ) = @_;

    my @parents;

    if ( $line =~ m/^\s*use\s+(base|parent)\s+(.*)/xms ) {
        ( my $list = $2 ) =~ s/\s+\#.*//;
        $list =~ s/[\r\n]//;

        while ( $list !~ /;\s*$/ && ( $_ = <$fh> ) ) {
            s/\s+#.*//;
            s/[\r\n]//;
            $list .= $_;
        }

        $list =~ s/;\s*$//;

        my (@mods) = Safe->new()->reval($list);
        push @parents, @mods;
    }

    return @parents;
}

sub _parse_method_call {
    my ( $self, $line ) = @_;

    if ( $line =~ m/\s+([A-Za-z_:]+?)(::|\->)(\w+?)\(/xms ) {
        my $package = $1;
        my $method = $3;

        if ( !$self->{_analyser}->{calls}->{$package} ) {
            $self->{_analyser}->{calls}->{$package} = [];
        }

        if ( $package !~ m/^(?:shift|self|this)$/xms ) {
            if ( !grep /^$method$/, @{ $self->{_analyser}->{calls}->{$package} } ) {
                push @{ $self->{_analyser}->{calls}->{$package} }, $method;
            }
        }
    }
}

1;
