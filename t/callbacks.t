use Test::More tests => 6;
BEGIN { use_ok('CGI::Application') };

use lib './t';
use strict;

$ENV{'CGI_APP_RETURN_ONLY'} = 1;
$ENV{'PRERUN_TEST'}         = 1;
$ENV{'POSTRUN_TEST'}        = 1;
$ENV{'TEARDOWN_TEST'}       = 1;
$ENV{'CALLBACK_TEST'}       = 1;

use CGI;
use TestAppCallbacks;
my $t1_obj = TestAppCallbacks->new();
my $t1_output = $t1_obj->run();

ok(!$ENV{'PRERUN_TEST'}, 'prerun');
ok(!$ENV{'POSTRUN_TEST'}, 'postrun');
ok(!$ENV{'TEARDOWN_TEST'}, 'teardown');
ok(!$ENV{'CALLBACK_TEST'}, 'callback');
like($t1_output, qr/test_mode return value/, 'test_mode');

