use lib "t/lib";
use Test::More tests => 8;
#use Plack::Test;
use Test::Requires qw(Plack::Loader LWP::UserAgent);
use Test::TCP;

use TestApp_PSGI_Callback;
use CGI::Application::PSGI;

# this first test does not use CGI::App but provides a benchmark to how how streaming works in plain old psgi
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

# now do it with CGI::Application
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
            my $cgiapp = TestApp_PSGI_Callback->new({ QUERY => CGI::PSGI->new($env) });
            return $cgiapp->run_as_psgi;
	    });
    },
);
