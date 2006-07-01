use Test::More tests=>14;

# Include the test hierarchy
use lib 't/lib';

BEGIN { use_ok('TestApp5'); };
BEGIN { use_ok('CGI'); };

# Prevent output to STDOUT
$ENV{CGI_APP_RETURN_ONLY} = 1;

###

my $test_name = "mode_param( path_info => 1 ) with PATH_INFO set.";

$ENV{PATH_INFO} = '/basic_test1';
my $app = TestApp5->new;
$app->mode_param( path_info => 1 );
my $out;
eval { $out = $app->run() };
is($@, '', 'avoided eval() death');
like($out,qr/Hello World/, $test_name);

###

$test_name = "mode_param( path_info => 1 ) without PATH_INFO set, but with rm.";
$ENV{PATH_INFO} = '' ;
my $q = CGI->new({ rm => 'basic_test1' });
 $app = TestApp5->new( QUERY => $q );
$app->mode_param( path_info => 1 );
eval { $out = $app->run() };
is($@, '', 'avoided eval() death');
like($out,qr/Hello World/, $test_name);

####

$test_name = "mode_param( param => 'alt_rm' ) ";
$ENV{PATH_INFO} = '';
$q = CGI->new({ alt_rm => 'basic_test1' });
 $app = TestApp5->new( QUERY => $q );
$app->mode_param( param => 'alt_rm' );
eval { $out = $app->run() };
is($@, '', 'avoided eval() death');
like($out,qr/Hello World/, $test_name);

###

$test_name = "mode_param( path_info => 2 ), expecting success ";
$ENV{PATH_INFO} = '/my_ses_id/basic_test1/foo';
 $app = TestApp5->new( QUERY => $q );
$app->mode_param( path_info => 2, );
eval { $out = $app->run() };
is($@, '', 'avoided eval() death');
like($out,qr/Hello World/, $test_name);

####

$test_name = "mode_param( path_info => 2, param => 'alt_rm' ), with path_info undef ";
$ENV{PATH_INFO} = '' ;
 $app = TestApp5->new( QUERY => $q );
$app->mode_param( path_info => 2, param => 'alt_rm' );
eval { $out = $app->run() };
is($@, '', 'avoided eval() death');
like($out,qr/Hello World/, $test_name);

####

$test_name = "mode_param( path_info => -2 ), expecting success ";
$ENV{PATH_INFO} = '/my_ses_id/basic_test1/foo';
 $app = TestApp5->new( QUERY => $q );
$app->mode_param( path_info => -2, );
eval { $out = $app->run() };
is($@, '', 'avoided eval() death');
like($out,qr/Hello World/, $test_name);

####
