requires 'DateTime';
requires 'DateTime::Format::RFC3339';
requires 'DateTimeX::TO_JSON';
requires 'Exception::Class';
requires 'File::ShareDir';
requires 'HTTP::Tiny';
requires 'IO::Socket::SSL';
requires 'IPC::Run3';
requires 'JSON';
requires 'Perl::Critic';
requires 'Perl::Metrics::Simple';
requires 'Readonly';
requires 'Template';
requires 'Template::Plugin::JSON';
requires 'Text::Unidecode';
requires 'Try::Tiny';
requires 'Unicode::Normalize';

recommends 'JSON::XS';

on 'test' => sub {
    requires 'Devel::Cover';
    requires 'Test::More';
};

on 'configure' => sub {
    requires 'Module::Build';
    requires 'Module::Build::Pluggable';
    requires 'Module::Build::Pluggable::CPANfile';
    requires 'PAR::Packer';
};
