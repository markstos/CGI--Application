use Test::More;
use Plack::Test;
use HTTP::Request::Common;

# Include the test hierarchy
use lib 't/lib';

use TestApp5;
use CGI::PSGI;

my $test_name = "mode_param( path_info => 1 ) with PATH_INFO set.";
test_psgi
    app => sub {
        my $env = shift;
        my $app = TestApp5->new( REQUEST => CGI::PSGI->new($env) );
        $app->mode_param( path_info => 1 );
        return $app->run;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/basic_test1');
        ok($res->is_success);
        like($res->content,qr/Hello World/, $test_name);

        my $res = $cb->(GET '/?rm=basic_test1');
        ok($res->is_success);
        like($res->content,qr/Hello World/, 
             "mode_param( path_info => 1 ) without PATH_INFO set, but with rm.");
    };

$test_name = "mode_param( param => 'alt_rm' ) ";
test_psgi
    app => sub {
        my $env = shift;
        my $app = TestApp5->new( REQUEST => CGI::PSGI->new($env) );
        $app->mode_param( param => 'alt_rm' );
        return $app->run;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/?alt_rm=basic_test1');
        ok($res->is_success);
        like($res->content,qr/Hello World/,
             $test_name);
    };



$test_name = "mode_param( path_info => 2 ), expecting success ";
test_psgi
    app => sub {
        my $env = shift;
        my $app = TestApp5->new( REQUEST => CGI::PSGI->new($env) );
        $app->mode_param( path_info => 2 );
        return $app->run;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/my_ses_id/basic_test1/foo');
        ok($res->is_success);
        like($res->content,qr/Hello World/,
             $test_name);
    };


$test_name = "mode_param( path_info => 2, param => 'alt_rm' ), with path_info undef ";
test_psgi
    app => sub {
        my $env = shift;
        my $app = TestApp5->new( REQUEST => CGI::PSGI->new($env) );
        $app->mode_param( path_info => 2, param => 'alt_rm' );
        return $app->run;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/?alt_rm=basic_test1');
        ok($res->is_success);
        like($res->content,qr/Hello World/,
             $test_name);
    };

$test_name = "mode_param( path_info => -2 ), expecting success ";
test_psgi
    app => sub {
        my $env = shift;
        my $app = TestApp5->new( REQUEST => CGI::PSGI->new($env) );
        $app->mode_param( path_info => -2, );
        return $app->run;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/my_ses_id/basic_test1/foo?alt_rm=basic_test1');
        ok($res->is_success);
        like($res->content,qr/Hello World/,
             $test_name);
    };

done_testing();
