use Test::More tests=>2;

# Include the test hierarchy
use lib './test';

use CGI;
use TestCGI;
use TestApp9;

# Prevent output to STDOUT
$ENV{CGI_APP_RETURN_ONLY} = 1;

# Query object may be initialized via new()
# to a non-CGI.pm object type
{
    my $cgi_obj = TestCGI->new();
    my $testapp = TestApp9->new(QUERY=>$cgi_obj);
    my $query_back = $testapp->query();
    isa_ok($query_back, "TestCGI");
}


# $CGIApp->header_type('none') returns only content.
{
    my $q = CGI->new({rm=>"noheader"});
    my $app = TestApp9->new(QUERY=>$q);
    my $output = $app->run();
    unlike($output, qr/^Content\-Type\:\ text\/html/, "Headers 'none'");
}
