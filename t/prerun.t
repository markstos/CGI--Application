use Test::More;

use CGI;
use CGI::PSGI;

# Include the test hierarchy
use lib 't/lib';

use Plack::Test;
use HTTP::Request::Common;
use TestApp6;
use CGI::PSGI;

# Test basic prerun() and get_current_runmode()
test_psgi
    app => sub { 
        my $env = shift;
        my $app = TestApp6->new( REQUEST => CGI::PSGI->new($env) );
        my $aref = $app->run;
        # Did the prerun work?
        is($app->param('PRERUN_RUNMODE'), 'prerun_test');

        # get_current_runmode() working?
        is($app->get_current_runmode(), 'prerun_test');

        return $aref;
    }, 
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/');
        like($res->header('Content-Type'), qr{text/html});
	    like($res->content, qr/Hello\ World\:\ prerun\_test\ OK/);
    };

# # Test basic prerun_mode()
test_psgi
    app => sub { 
        my $env = shift;
        my $app = TestApp6->new( REQUEST => CGI::PSGI->new($env) );
        my $aref = $app->run;

        # get_current_runmode() working?
        is($app->get_current_runmode(), 'new_prerun_mode_test');

        return $aref;
    }, 
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/?rm=prerun_mode_test');
        like($res->header('Content-Type'), qr{text/html});
	    like($res->content, qr/Hello\ World\:\ new\_prerun\_mode\_test\ OK/);
    };

# # Test fail-case for prerun_mode()
test_psgi
    app => sub { 
        my $env = shift;
        my $app = TestApp6->new( REQUEST => CGI::PSGI->new($env) );
        my $aref = $app->run;

 	    eval {
 	    	$aref = $app->run();
 	    };
 
 	    my $eval_error = $@;
 
 	    # Should result in an error
 	    like($eval_error, qr/prerun\_mode\(\) can only be called within cgiapp\_prerun\(\)/);

        return $aref;
    }, 
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/?rm=illegal_prerun_mode');
    };

# # Test fail-case for prerun_mode() called from setup()
$ENV{PRERUN_IN_SETUP} = 1;
{
	eval { TestApp6->new };
	my $eval_error = $@;

	# Should result in an error
	like($eval_error, qr/prerun\_mode\(\) can only be called within cgiapp\_prerun\(\)/);
}

done_testing();
