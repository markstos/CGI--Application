use Test::More;

use CGI;
use CGI::PSGI;

# Include the test hierarchy
use lib 't/lib';

use TestApp8;
use Plack::Test;
use HTTP::Request::Common;

test_psgi
    app => TestApp8->psgi_app(),
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/');
        like($res->header('Content-Type'), qr{text/html});
        like($res->content,qr/Hello\ World\:\ testcgi1\_mode\ OK/);
    };

test_psgi
    app => TestApp8->psgi_app(),
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/?rm=testcgi2_mode');
        like($res->header('Content-Type'), qr{text/html});
        like($res->content,qr/Hello\ World\:\ testcgi2\_mode\ OK/);
    };

# test_psgi
#     app => TestApp8->psgi_app(),
#     client => sub {
#         my $res = $cb->(GET '/?rm=testcgi3_mode');
#         like($res->header('Content-Type'), qr{text/html});
#         like($res->content,qr/Hello\ World\:\ testcgi3\_mode\ OK/);
#     };


done_testing();
