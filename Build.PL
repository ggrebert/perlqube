use strict;
use warnings;

use Module::Build::Pluggable ( 'CPANfile' );

my $builder = Module::Build::Pluggable->new(
    module_name          => 'PerlQube',
    dist_abstract        => 'PerlQube',
    dist_author          => 'SII',
    dist_version         => '0.1',
    recursive_test_files => 1,
    share_dir            => {
        module => {
            PerlQube => 'templates'
        }
    }
);

$builder->create_build_script();
