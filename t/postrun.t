use Test::More;

# Include the test hierarchy
use lib 't/lib';

use Plack::Test;
use HTTP::Request::Common;
use CGI::PSGI;
use TestCGI;
use TestApp9;

# Test making a modification to the output body
test_psgi
    app => TestApp9->psgi_app,
    client => sub {
        my $cb = shift;

        my $res = $cb->(GET '/?rm=postrun_body');
        like($res->header('Content-Type'), qr{text/html});
        like($res->content, qr/Hello world: postrun_body/, "Hello world: postrun_body");
        like($res->content, qr/postrun\ was\ here/, "Postrun was here");

    };

# Test changing HTTP headers in postrun
test_psgi
    app => TestApp9->psgi_app,
    client => sub {
        my $cb = shift;

        my $res = $cb->(GET '/?rm=postrun_header');
        is($res->code, 302, "Postrun header is redirect");
        like($res->as_string, qr/postrun.html/, "Postrun header is redirect to postrun.html");
        like($res->as_string, qr/Hello world: postrun_header/, "Hello world: postrun_header");
        unlike($res->as_string, qr/postrun\ was\ here/, "Postrun was NOT here");
    };


done_testing();
