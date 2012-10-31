use Test::More;

# Include the test hierarchy
use lib 't/lib';
use TestApp13;


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


done_testing;
