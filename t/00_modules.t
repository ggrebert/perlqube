#!perl

use strict;
use warnings;

use Test::More;

my $PACKAGES = {
    'PerlQube' => { can => [ 'new', 'critique' ] },
    'PerlQube::Command' => { can => [ 'run', 'help', 'version' ] },
    'PerlQube::Config' => { can => [ 'new' ] },
    'PerlQube::Exception' => { },
    'PerlQube::Git' => {
        can => [
            'new',
            'get_modified_files',
            'get_files_status',
            'get_file_status',
            'is_new_file',
            'is_modified_file',
            'is_modified_line',
            'filter',
            'is_new_violation',
            'is_already_exists',
        ]
    },
    'PerlQube::GitLab' => {
        can => [
            'new',
            'get_last_scan',
            'post_commit_comment',
        ]
    },
    'PerlQube::Scan' => {
        can => [
            'new',
            'scan',
            'perlcritic',
            'metrics',
            'analyzer',
        ]
    },
    'PerlQube::Output' => {
        can => [
            'new',
            'process',
            'severity_to_str',
        ]
    },
    'PerlQube::Output::Json' => { },
    'PerlQube::Output::GitLab' => { },
    'PerlQube::Output::Html' => { },
    'PerlQube::Output::Html::Bootstrap4' => { },
};

my $test_count = 0;
foreach my $package (values %{ $PACKAGES }) {
    $test_count++;

    if ($package->{can}) {
        $test_count += scalar @{ $package->{can} };
    }
}

plan tests => $test_count;

diag( "Testing PerlQube under Perl $], $^X" );

foreach my $package (keys %{ $PACKAGES }) {
    use_ok($package);

    if ($PACKAGES->{$package}->{can}) {
        foreach my $method (@{ $PACKAGES->{$package}->{can} }) {
            can_ok($package, $method);
        }
    }
}

done_testing();
