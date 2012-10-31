
use Test::More;
use Plack::Test;
use HTTP::Request::Common;

# Include the test hierarchy
use lib 't/lib';

use CGI::PSGI;
use TestCGI;
use TestApp9;


# Query object may be initialized via new()
# to a non-CGI.pm object type
test_psgi
    app => sub {
        my $env = shift;
        my $app = TestApp9->new( REQUEST => TestCGI->new($env) );
        isa_ok($app->req, 'TestCGI');
        return $app->run;
    },
    client => sub {
        my $cb = shift;

        # # $CGIApp->header_type('none') returns only content.
        my $res = $cb->(GET '/?rm=noheader');
        unlike($res->as_string, qr/^Content\-Type\:\ text\/html/, "Headers 'none'");
    };

done_testing;
