#!perl

use strict;
use warnings;

use Test::More;
use App::Cmd::Tester;

use App::Automated::Letter;
use Data::Dumper;

use Cwd;
use File::Basename ();
use File::Path;
use File::Spec ();
use JSON::Any;
require DBD::File; # prevent DBD::File writes to STDERR because of I/O redirection in App::Cmd::Tester

my $dir = File::Spec->catdir( getcwd(), 'test_output' );

rmtree $dir;
END { rmtree $dir }
mkpath $dir;

$ENV{APP_AUTOLTTR_CONFIGBASE} = 'examples';
my $result = test_app( 'App::Automated::Letter' => ["serial", "--body", "t/example-body.tex"] );

is( $result->stderr, '',    'nothing sent to sderr' );
is( $result->error,  undef, 'threw no exceptions' );

ok( -f File::Spec->catfile( File::Spec->tmpdir(), "example-body-0.tex" ), "generated file exists" );

done_testing();
