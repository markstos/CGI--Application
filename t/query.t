# test the query() method

use Test::More 'no_plan';
use CGI;

# Include the test hierarchy
use lib 't/lib';

use TestApp14;

# Prevent output to STDOUT
$ENV{CGI_APP_RETURN_ONLY} = 1;

# Test query()
{
    my $cgi = CGI->new('message=hello');
	my $ta_obj = TestApp14->new(QUERY => $cgi);
	my $output = $ta_obj->run();

	like($output, qr/---->hello<----/);

    my $cgi2 = CGI->new('message=goodbye');
    $ta_obj->query($cgi2);
	$output = $ta_obj->run();

	like($output, qr/---->goodbye<----/);
}
