use Test::More tests => 11;

# Need CGI.pm for tests
use CGI;



SKIP: {
	# Check for Net::SMTP
	eval { require Net::SMTP; };
	skip("Net::SMTP is not installed.  CGI::Application::Mailform requires Net::SMTP.", 4)
		if ($@);

	# Can we even use this module?
	require_ok('CGI::Application::Mailform');

	my $mf = CGI::Application::Mailform->new();

	# Is it a Mailform?
	isa_ok($mf, 'CGI::Application::Mailform');

	# If it a CGI-App?
	isa_ok($mf, 'CGI::Application');

	# Did it inherit the run method?
	can_ok($mf, qw/run/);
}

# Instantiate CGI::Application::Mailform
# run() CGI::Application::Mailform object.
# Expect redirect header + body
{
	my $app = CGI::Application::Mailform->new();
	isa_ok($app, 'CGI::Application::Mailform');

	$app->query(CGI->new(""));
	$app->param(MAIL_FROM=>'a');
		$app->param(MAIL_TO => 'b');
		$app->param(HTMLFORM_REDIRECT_URL => 'redirect_url');
		$app->param(SUCCESS_REDIRECT_URL => 'd');
		$app->param(FORM_FIELDS => []);


	response_like(
		$app,
		qr/^Status: 302/,
		qr/Continue: <a href="redirect_url">redirect_url<\/a>/,
		'TestApp, redirect_test'
	);
}

# Instantiate CGI::Application::Mailform with missing params
# run() CGI::Application::Mailform object.
# Expect error
{
	my $app = CGI::Application::Mailform->new();
	isa_ok($app, 'CGI::Application::Mailform');

	$app->query(CGI->new(""));

    my $output;
	eval { $output = $app->run; };

	like( $@, qr/Missing or invalid required parameters/, "Missing paramters");
}

# Instantiate CGI::Application::Mailform with invalid params
# run() CGI::Application::Mailform object.
# Expect error
{
	my $app = CGI::Application::Mailform->new();
	isa_ok($app, 'CGI::Application::Mailform');

	$app->query(CGI->new(""));
	$app->param(MAIL_FROM=>'');
	$app->param(FORM_FIELDS => 'not an arrayref');


	my $output;
	eval { $output = $app->run; };

	like( $@, qr/Missing or invalid required parameters/, "Missing paramters");
}


sub response_like {
	my ($app, $header_re, $body_re, $comment) = @_;

	local $ENV{CGI_APP_RETURN_ONLY} = 1;
	my $output = $app->run;
	my ($header, $body) = split /\r\n\r\n/m, $output;
	like($header, $header_re, "$comment (header match)");
	like($body, $body_re, "$comment (body match)");
}
