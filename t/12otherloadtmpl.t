use Test::More tests=>3;

# Include the test hierarchy
use lib 't/lib';

BEGIN {
	use_ok('TestApp13');
};

# Prevent output to STDOUT
$ENV{CGI_APP_RETURN_ONLY} = 1;

# testing filehandle template
{
    my $app = TestApp13->new;
    my $output = $app->run();
    like($output, qr/HELLO/, "filehandle template works");
}

{
    my $q = CGI->new({rm=>"mode2"});
    my $app = TestApp13->new(QUERY=>$q);
    my $output = $app->run();
    like($output, qr/HELLO/, "scalar template works");
}

