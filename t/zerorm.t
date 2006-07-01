use Test::More tests=>1;
use strict;

# Include the test hierarchy
use lib 't/lib';

use TestApp10;

# Prevent output to STDOUT
$ENV{CGI_APP_RETURN_ONLY} = 1;

# A runmode of '0' should be allowed
{
    my $app = TestApp10->new;
       my $output = $app->run();
    like($output, qr/Success!$/, "Runmode 0 works");
}

