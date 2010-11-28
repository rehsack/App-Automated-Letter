#!perl -T

use Test::More tests => 1;

BEGIN {
    use_ok( 'App::Automated::Letter' ) || print "Bail out!
";
}

diag( "Testing App::Automated::Letter $App::Automated::Letter::VERSION, Perl $], $^X" );
