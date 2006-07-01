use Test::More tests => 7;

use CGI;

# Include the test hierarchy
use lib 't/lib';

# Can we even use this module?
use_ok('TestApp8');

# Prevent output to STDOUT
$ENV{CGI_APP_RETURN_ONLY} = 1;

# Test array-ref mode
{
	my $ta_obj = TestApp8->new();
	my $output = $ta_obj->run();

	# Did the run mode work?
	like($output, qr/^Content\-Type\:\ text\/html/);
	like($output, qr/Hello\ World\:\ testcgi1\_mode\ OK/);
}


{
	my $q = CGI->new({rm=>testcgi2_mode});
	my $ta_obj = TestApp8->new(QUERY=>$q);
	my $output = $ta_obj->run();

	# Did the run mode work?
	like($output, qr/^Content\-Type\:\ text\/html/);
	like($output, qr/Hello\ World\:\ testcgi2\_mode\ OK/);
}


{
	my $q = CGI->new({rm=>testcgi3_mode});
	my $ta_obj = TestApp8->new(QUERY=>$q);
	my $output = $ta_obj->run();

	# Did the run mode work?
	like($output, qr/^Content\-Type\:\ text\/html/);
	like($output, qr/Hello\ World\:\ testcgi3\_mode\ OK/);
}


###############
####  EOF  ####
###############
