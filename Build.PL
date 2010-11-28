use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'App::Automated::Letter',
    license             => 'perl',
    dist_author         => q{Jens Rehsack <rehsack@cpan.org>},
    dist_version_from   => 'lib/App/Automated/Letter.pm',
    build_requires => {
	'App::Cmd::Tester' => '0.300',
	'DBD::CSV' => '0.31',
	'File::Slurp' => 0,
	'JSON::Any' => 0,
        'Test::More' => '0.90',
    },
    requires => {
	'App::Cmd' => '0.300',
	'Carp' => 0,
	'Config::Any' => 0,
	'File::ConfigDir' => 0.003,
	'File::Find::Rule' => '0.30',
	'Template' => '2.00',
	'Template::Plugin::Latex' => '3.01',
    },
    share_dir          => { dist => [ 'share', ], },
    add_to_cleanup      => [ 'App-Serial-Letter-*' ],
);

$builder->create_build_script();
