requires 'Exception::Class';
requires 'IPC::Run3';
requires 'JSON';
requires 'Perl::Critic';
requires 'Readonly';

recommends 'JSON::XS';

on 'test' => sub {
    requires 'Test::More';
};

on 'configure' => sub {
    requires 'Module::Build';
    requires 'Module::Build::Pluggable';
    requires 'Module::Build::Pluggable::CPANfile';
    requires 'PAR::Packer';
};
