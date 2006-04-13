# $Id: 01cgiapp.t,v 1.12 2004/05/08 21:08:18 mark Exp $

use strict;
use Test::More tests => 98;

BEGIN{use_ok('CGI::Application');}

# Need CGI.pm for tests
use CGI;

# bring in testing hierarchy
use lib './test';
use TestApp;
use TestApp2;
use TestApp3;
use TestApp4;
use TestApp5;

$ENV{CGI_APP_RETURN_ONLY} = 1;

# Instantiate CGI::Application
# run() CGI::Application object.  Expect header + output dump_html()
{
	my $app = CGI::Application->new();
	ok(ref $app, 'CGI::Application');
	ok($app->isa('CGI::Application'));
	$app->query(CGI->new(""));
	my $output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/Query Environment:/);
}

# Instantiate CGI::Application sub-class.
# run() CGI::Application sub-class.  Expect HTTP header + 'Hello World: basic_test'.
{
	my $app = TestApp->new(QUERY=>CGI->new(""));
	ok(ref $app);
	ok($app->isa('CGI::Application'));
	my $output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/Hello World: basic_test/);
}


# run() CGI::Application sub-class, in run mode 'redirect_test'.  Expect HTTP redirect header + 'Hello World: redirect_test'.
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'redirect_test'}));
	my $output = $app->run();
	like($output, qr/^Status: 302/);
	like($output, qr/Hello World: redirect_test/);
}


# run() CGI::Application sub-class, in run mode 'cookie_test'.  Expect HTTP header w/ cookie 'c_name' => 'c_value' + 'Hello World: cookie_test'.
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'cookie_test'}));
	my $output = $app->run();
	like($output, qr/^Set-Cookie: c_name=c_value/);
	like($output, qr/Hello World: cookie_test/);
}


# run() CGI::Application sub-class, in run mode 'tmpl_test'.  Expect HTTP header + 'Hello World: tmpl_test'.
{
	my $app = TestApp->new(TMPL_PATH=>'test/templates/');
	$app->query(CGI->new({'test_rm' => 'tmpl_test'}));
	my $output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/---->Hello World: tmpl_test<----/);
}


# run() CGI::Application sub-class, in run mode 'tmpl_badparam_test'.  Expect HTTP header + 'Hello World: tmpl_badparam_test'.
{
	my $app = TestApp->new(TMPL_PATH=>'test/templates/');
	$app->query(CGI->new({'test_rm' => 'tmpl_badparam_test'}));
	my $output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/---->Hello World: tmpl_badparam_test<----/);
}


# Instantiate and call run_mode 'eval_test'.  Expect 'eval_test OK' in output.
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'eval_test'}));
	my $output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/Hello World: eval_test OK/);
}

# Test to make sure cgiapp_init() was called in inherited class.
{
	my $app = TestApp2->new();
	my $init_state = $app->param('CGIAPP_INIT');
	ok(defined $init_state);
	is($init_state, 'true');
}


# Test to make sure mode_param() can contain subref
{
	my $app = TestApp3->new();
	$app->query(CGI->new({'go_to_mode' => 'subref_modeparam'}));
	my $output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/Hello World: subref_modeparam OK/);
}


# Test to make sure that "false" run modes are valid -- will not default to start_mode()
{
	my $app = TestApp3->new();
	$app->query(CGI->new({'go_to_mode' => '0'}));
	my $output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/Hello World: blank_mode OK/);
}

# Test to make sure that undef run modes will default to start_mode()
{
	my $app = TestApp3->new();
	$app->query(CGI->new({'go_to_mode' => 'undef_rm'}));
	my $output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/Hello World: default_mode OK/);
}


# Test run modes returning scalar-refs instead of scalars
{
	my $app = TestApp4->new(QUERY=>CGI->new(""));
	my $output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/Hello World: subref_test OK/);
}


# Test "AUTOLOAD" run mode
{
	my $app = TestApp4->new();
	$app->query(CGI->new({'rm' => 'undefined_mode'}));

	my $output = $app->run();
	   
	like($output, qr{^Content-Type: text/html});
	like($output, qr/Hello World: undefined_mode OK/);
}


# Can we incrementally add run modes?
{
	my $app;
	my $output;

	# Mode: BasicTest
	$app = TestApp5->new();
	$app->query(CGI->new({'rm' => 'basic_test1'}));
	$output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/Hello World: basic_test1/);

	# Mode: BasicTest2
	$app = TestApp5->new();
	$app->query(CGI->new({'rm' => 'basic_test2'}));
	$output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/Hello World: basic_test2/);

	# Mode: BasicTest3
	$app = TestApp5->new();
	$app->query(CGI->new({'rm' => 'basic_test3'}));
	$output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/Hello World: basic_test3/);
}


# Test 18: Can we add params in batches?
{
	my $app;
	my @params = ('', 'one', 'two', 'new three', 'four', 'new five', 'six', 'seven', 'eight');

	$app = TestApp5->new(
		PARAMS => {
			P1 => 'one',
			P2 => 'two'
		}
	);

	my @plist = ();

	# Do params set via new still get set?
	@plist = sort $app->param();
	is_deeply(\@plist, ['P1', 'P2']);

        is($app->param("P$_"), $params[$_]) for 1..2;


	# Can we still augment params one at a time?
	$app->param('P3', 'three');
	@plist = sort $app->param();
	is_deeply(\@plist, ['P1', 'P2', 'P3']);
        is($app->param("P$_"), $params[$_]) for 1..2;
        is($app->param("P3"), 'three');

	# Does a hash work?  (Should return undef)
	my $pt3val = $app->param(
		'P3' => 'new three',
		'P4' => 'four',
		'P5' => 'five'
	);
	@plist = sort $app->param();
	is_deeply(\@plist, ['P1', 'P2', 'P3', 'P4', 'P5']);
        is($app->param("P$_"), $params[$_]) for 1..4;
        is($app->param("P5"), 'five');
	ok(not(defined($pt3val)));


	# What about a hash-ref?  (Should return undef)
	my $pt4val = $app->param({
		'P5' => 'new five',
		'P6' => 'six',
		'P7' => 'seven',
	});
	@plist = sort $app->param();
	is_deeply(\@plist, ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7']);
        is($app->param("P$_"), $params[$_]) for 1..7;
	ok(not(defined($pt4val)));

	# What about a simple pass-through?  (Should return param value)
	my $pt5val = $app->param('P8', 'eight');
	@plist = sort $app->param();
	is_deeply(\@plist, ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8']);
        is($app->param("P$_"), $params[$_]) for 1..8;
	is($pt5val, 'eight');
}


# test setting header_props before header_type 
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'props_before_redirect_test'}));
	my $output = $app->run();

	like($output, qr/test: 1/i);
	like($output, qr/Status: 302/);
}

# testing setting header_props more than once
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'header_props_twice_nomerge'}));
	my $output = $app->run();

	like($output, qr/test: Updated/i);
	unlike($output, qr/second-header: 1/);
	unlike($output, qr/Test2:/);
}

# testing header_add with arrayref
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'header_add_arrayref_test'}));
	my $output = $app->run();

	like($output, qr/Set-Cookie: cookie1=header_add/);
	like($output, qr/Set-Cookie: cookie2=header_add/);
}

# make sure header_add does not clobber earlier headers
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'header_props_before_header_add'}));
	my $output = $app->run();

	like($output, qr/Set-Cookie: cookie1=header_props/);
	like($output, qr/Set-Cookie: cookie2=header_add/);
}

# make sure header_add works after header_props is called
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'header_add_after_header_props'}));
	my $output = $app->run();

	like($output, qr/Set-Cookie: cookie2=header_add/);
}

# test use of TMPL_PATH without trailing slash
{
	my $app = TestApp->new(TMPL_PATH=>'test/templates');
	$app->query(CGI->new({'test_rm' => 'tmpl_badparam_test'}));
	my $output = $app->run();
	like($output, qr{^Content-Type: text/html});
	like($output, qr/---->Hello World: tmpl_badparam_test<----/);
}

# test setting header_props before header_type 
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'props_before_redirect_test'}));
	my $output = $app->run();

	like($output, qr/test: 1/i);
	like($output, qr/Status: 302/);
}


# test delete() method by first setting some params and then deleting them
{
	my $app = TestApp5->new();
	$app->param(
        	P1 => 'one',
        	P2 => 'two',
        	P3 => 'three');
	#a valid delete
	$app->delete('P2');
        my @params = sort $app->param();

	is_deeply(\@params, ['P1', 'P3']);
        is($app->param('P1'), 'one');
        ok(not defined($app->param('P2')));
        is($app->param('P3'), 'three');


	#an invalid delete
	my $result = $app->delete('P4');
	
	ok(not defined($result));
        is($app->param('P1'), 'one');
        ok(not defined($app->param('P4')));
        is($app->param('P3'), 'three');
}

###

my $t27_ta_obj = CGI::Application->new(TMPL_PATH => [qw(test/templates /some/other/test/path)]);
my ($t1, $t2) = (0,0);
my $tmpl_path = $t27_ta_obj->tmpl_path();

ok((ref $tmpl_path eq 'ARRAY'), 'tmpl_path returns array ref');
ok(($tmpl_path->[0] eq 'test/templates'), 'tmpl_path first element is correct');
ok(($tmpl_path->[1] eq '/some/other/test/path'), 'tmpl_path  second element is correct');

my $tmpl = $t27_ta_obj->load_tmpl('test.tmpl');
$tmpl_path = $tmpl->{options}->{path};

ok((ref $tmpl_path eq 'ARRAY'), 'tmpl_path from H::T obj returns array ref');
ok(($tmpl_path->[0] eq 'test/templates'), 'tmpl_path from H::T obj first element is correct');
ok(($tmpl_path->[1] eq '/some/other/test/path'), 'tmpl_path from H::T obj  second element is correct');

# All done!
