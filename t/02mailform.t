use Test::More qw(no_plan);

SKIP: {
	# Check for Net::SMTP
	eval { require Net::SMTP; };
	skip("Net::SMTP is not installed.  CGI::Application::Mailform tests have been skipped.", 3)
		if ($@);

	# Can we even use this module?
	require_ok('CGI::Application::Mailform');

	my $mf = CGI::Application::Mailform->new();
	isa_ok($mf, 'CGI::Application::Mailform');
	isa_ok($mf, 'CGI::Application');

	can_ok($mf, qw/run/);
}
