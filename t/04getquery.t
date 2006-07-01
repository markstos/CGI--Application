use Test::More tests => 3;

# Include the test hierarchy
use lib 't/lib';

# Can we even use this module?
use_ok('TestApp7');

# Prevent output to STDOUT
$ENV{CGI_APP_RETURN_ONLY} = 1;

# Test basic cgiapp_get_query()
{
	my $ta_obj = TestApp7->new();
	my $output = $ta_obj->run();

	# Did the run mode work?
	like($output, qr/^Content\-Type\:\ text\/html/);
	like($output, qr/Hello\ World\:\ testcgi\_mode\ OK/);
}


###############
####  EOF  ####
###############
