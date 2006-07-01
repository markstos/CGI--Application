
use strict;
use Test::More tests => 6;

BEGIN{use_ok('CGI::Application');}

# Need CGI.pm for tests
use CGI;

$ENV{CGI_APP_RETURN_ONLY} = 1;

{
	my $app = CGI::Application->new();
	isa_ok($app, 'CGI::Application');

  is($app->mode_param, "rm", "default mode_param is rm");
  is($app->mode_param(''), "rm", "we can't change it to q{}");
  is($app->mode_param(undef), "rm", "we can't change it to undef");
  is($app->mode_param(0), "0", "we CAN change it to 0");
}
