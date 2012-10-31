use Test::More;
use strict;

# Include the test hierarchy
use lib 't/lib';

use TestApp10;

# A runmode of '0' should be allowed
my $psgi_aref = TestApp10->psgi_app->();
like( $psgi_aref->[2][0], qr/Success!$/, "Runmode 0 works");

done_testing();
