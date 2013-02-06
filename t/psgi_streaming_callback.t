use lib "t/lib";
use Test::More tests => 22;
#use Plack::Test;
use Test::Requires qw(Plack::Loader LWP::UserAgent);
use Test::TCP;

use TestApp_PSGI_Callback;
use CGI::Application::PSGI;

my $test_file = 't/test_file_to_stream.txt';

diag "this first test does not use CGI::App but provides a benchmark to how how streaming callback works in plain old psgi";

test_tcp(
    client => sub {
        my $port = shift;
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get("http://127.0.0.1:$port/");
        like $res->content, qr/check 1: \d+\n/;
        like $res->content, qr/check 5: \d+\n/;
        unlike $res->content, qr/Content-Type/, "No headers";
        like $res->content_type, qr/plain/;
    },
    server => sub {
        my $port = shift;
        Plack::Loader->auto(port => $port)->run(sub {
        	my $env = shift;
        	return sub {
  		        my $respond = shift;
	   	     	use Data::Dumper;
	        	my $w = $respond->([ 200, ['X-Foo' => 'bar', 'Content-Type' => 'text/plain'] ]);
	        	foreach my $i (1..5) {
	            	#sleep 1;
	            	$w->write("check $i: " . time . "\n");
	        	}
        	};
	    });
    },
);

diag "another test this time returning a file handle";

test_tcp(
    client => sub {
        my $port = shift;
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get("http://127.0.0.1:$port/");
        like $res->content, qr/test 1\n/;
        like $res->content, qr/test 3\n/;
        unlike $res->content, qr/Content-Type/, "No headers";
        like $res->content_type, qr/plain/;
        is $res->content_length, 21;
    },
    server => sub {
        my $port = shift;
        Plack::Loader->auto(port => $port)->run(sub {
        	open my $fh, "<", $test_file or die "OOPS! $!";
        	return [ 200, ['X-Foo' => 'bar', 'Content-Type' => 'text/plain'], $fh];
	    });
    },
);

diag "now do streaming with CGI::Application - return file handle";
test_tcp(
    client => sub {
        my $port = shift;
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get("http://127.0.0.1:$port/?rm=file_handle");
        like $res->content, qr/test 1+\n/;
        like $res->content, qr/test 3\n/;
        unlike $res->content, qr/Content-Type/, "No headers";
        like $res->content_type, qr/plain/;
        is $res->content_length, 21;
    },
    server => sub {
        my $port = shift;
        Plack::Loader->auto(port => $port)->run(sub {
        	my $env = shift;
            my $cgiapp = TestApp_PSGI_Callback->new({ QUERY => CGI::PSGI->new($env) });
            return $cgiapp->run_as_psgi;
	    });
    },
);

diag "now do streaming with CGI::Application - return subref";
test_tcp(
    client => sub {
        my $port = shift;
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get("http://127.0.0.1:$port/?rm=callback_subref");
        like $res->content, qr/check 1: \d+\n/;
        like $res->content, qr/check 5: \d+\n/;
        unlike $res->content, qr/Content-Type/, "No headers";
        like $res->content_type, qr/plain/;
    },
    server => sub {
        my $port = shift;
        Plack::Loader->auto(port => $port)->run(sub {
        	my $env = shift;
            my $cgiapp = TestApp_PSGI_Callback->new({ QUERY => CGI::PSGI->new($env) });
            return $cgiapp->run_as_psgi;
	    });
    },
);

diag "now do streaming with CGI::Application - excplicit callback method";
test_tcp(
    client => sub {
        my $port = shift;
        my $ua = LWP::UserAgent->new;
        my $res = $ua->get("http://127.0.0.1:$port/?rm=callback_explicit");
        like $res->content, qr/check 1: \d+\n/;
        like $res->content, qr/check 5: \d+\n/;
        unlike $res->content, qr/Content-Type/, "No headers";
        like $res->content_type, qr/plain/;
    },
    server => sub {
        my $port = shift;
        Plack::Loader->auto(port => $port)->run(sub {
        	my $env = shift;
            my $cgiapp = TestApp_PSGI_Callback->new({ QUERY => CGI::PSGI->new($env) });
            return $cgiapp->run_as_psgi;
	    });
    },
);
