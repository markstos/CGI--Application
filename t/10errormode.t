use Test::More tests=>6;

# Include the test hierarchy
use lib 't/lib';

BEGIN {
	use_ok('TestApp11');
	use_ok('TestApp12');
};

# Prevent output to STDOUT
$ENV{CGI_APP_RETURN_ONLY} = 1;

# Usage of error_mode will catch a runtime failure
{
    my $app = TestApp11->new;
    my $output = $app->run();
    like($output, qr/Success!/, "Errormode works");
    like($output, qr/mode1 failed/, 'Errormode received $@ as value');
}

# Need to see what happens when error_mode itself fails
{
    my $app = TestApp12->new;
    my $output;
    eval {
        $output = $app->run();
    };

    ok( defined $@, "Make sure the error_mode did fail" );
    like($@, qr/Oops/, "Errormode fails correctly");
}
