# test the req() method

use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use CGI::PSGI;

use PSGI::Application;

# Include the test hierarchy
use lib 't/lib';


# Test setting a new request object;
test_psgi
    app => sub {
        my $env = shift;

        my $app = PSGI::Application->new( REQUEST => CGI::PSGI->new({ %$env, QUERY_STRING => 'message=hello' }) );
        is $app->req->param('message'), 'hello', 'reality check setting and getting a request param';

        $app->req( CGI::PSGI->new({ %$env, QUERY_STRING => 'message=goodbye' }));
        is $app->req->param('message'), 'goodbye', 'req($new_query) reality check';
        return $app->run;
    },
    client => sub {
        my $cb = shift;
        $cb->(GET '/');
    };

done_testing();
