use Test::More;

# Include the test hierarchy
use lib 't/lib';

use TestApp7;
use Try::Tiny;

# Test basic get_request()
TODO: {
    local $TODO = "not sure if we are going to keep supporting get_request (was cgiapp_get_query)";
    my $output;
    try {
	my $ta_obj = TestApp7->new( );
	$output = $ta_obj->run();

    };
	# Did the run mode work?
	like($output, qr/^Content\-Type\:\ text\/html/);
	like($output, qr/Hello\ World\:\ testcgi\_mode\ OK/);
}

done_testing();

