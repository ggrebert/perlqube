package PerlQube::GitLab;

use strict;
use warnings;

use Data::Dumper;
use HTTP::Tiny;
use IO::Socket::SSL;
use JSON;
use PerlQube::Exception;

sub new {
    my ( $class, $opts, $config ) = @_;

    my $self = bless { config => $config }, $class;

    $self->{token} = $opts->{gitlab_token};

    $self->{url} = $self->_init_url($opts);

    $self->{project} = $opts->{gitlab_id} ||
                       $ENV{CI_MERGE_REQUEST_PROJECT_ID} ||
                       $ENV{CI_PROJECT_ID} ||
                       PerlQube::Exception::Git->throw('Invalid GitLab project id.');

    return $self;
}

sub get_last_scan {
    my ( $self ) = @_;

    if ( !$self->{_last_scan} ) {
        my $ref = $self->{config}->{git}->{base};
        my $path = $self->{config}->{opts}->{json};
        my $job = $ENV{CI_JOB_NAME};

        my $url = "$self->{url}/api/v4/projects/$self->{project}/jobs/artifacts/$ref/raw/$path?job=$job";

        my $http = $self->_get_client;

        my $response = $http->get($url);

        if ( !$response->{success} ) {
            PerlQube::Exception::Git->throw('Error while fetching last scan result.');
        }

        $self->{_last_scan} = JSON->new->decode( $response->{content} );
    }

    return $self->{_last_scan};
}

sub post_commit_comment {
    my ( $self, $note, $path, $line, $line_type ) = @_;

    my $http = $self->_get_client;
    my $sha = $self->{config}->{git}->{ref};
    my $project = $self->{project};
    my $url = "$self->{url}/api/v4/projects/$project/repository/commits/$sha/comments";

    my $response = $http->post_form($url, {
        note => $note,
        path => $path,
        line => $line,
        line_type => $line_type,
    });

    if ( !$response->{success} ) {
        warn 'Error while reporting violation: ' . Data::Dumper::Dumper($response);
    }

    return $response->{success};
}

sub _get_client {
    my ( $self ) = @_;

    my $headers = {};
    if ($self->{token}) {
        $headers->{'PRIVATE-TOKEN'} = $self->{token};
    }
    elsif ($ENV{CI_JOB_TOKEN}) {
        $headers->{'JOB-TOKEN'} = $ENV{CI_JOB_TOKEN};
    }

    return HTTP::Tiny->new(
        default_headers => $headers,
        verify_SSL => 0,
    );
}

sub _init_url {
    my ( $self, $opts ) = @_;

    my $url = $opts->{gitlab_url} || $ENV{CI_PROJECT_URL};

    my @retval = $url =~ m/(https?:\/\/[^\/]+)/xms;

    return $retval[0] || PerlQube::Exception::Git->throw('Invalid GitLab url.');
}

1;
