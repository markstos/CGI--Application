use Test::More tests => 4;

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
