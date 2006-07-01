
use strict;
use Test::More tests => 110;

BEGIN{use_ok('CGI::Application');}

# Need CGI.pm for tests
use CGI;

# bring in testing hierarchy
use lib 't/lib';
use TestApp;
use TestApp2;
use TestApp3;
use TestApp4;
use TestApp5;

$ENV{CGI_APP_RETURN_ONLY} = 1;

sub response_like {
	my ($app, $header_re, $body_re, $comment) = @_;

	local $ENV{CGI_APP_RETURN_ONLY} = 1;
	my $output = $app->run;
	my ($header, $body) = split /\r\n\r\n/m, $output;
	like($header, $header_re, "$comment (header match)");
	like($body,	 $body_re,	 "$comment (body match)");
}

# Instantiate CGI::Application
# run() CGI::Application object.	Expect header + output dump_html()
{
	my $app = CGI::Application->new();
	isa_ok($app, 'CGI::Application');

	$app->query(CGI->new(""));
	my $output = $app->run();

	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/Query Environment:/,
		'base class response',
	);
}

# Instantiate CGI::Application sub-class.
# run() CGI::Application sub-class. 
# Expect HTTP header + 'Hello World: basic_test'.
{
	my $app = TestApp->new(QUERY => CGI->new(""));
	isa_ok($app, 'CGI::Application');

	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/Hello World: basic_test/,
		'TestApp, blank query',
	);
}


# Non-hash references are invalid for PARAMS.
{
  my $app = eval { TestApp->new(PARAMS => [ 1, 2, 3, ]); };

  like($@, qr/not a hash ref/, "PARAMS must be a hashref!");
}

# run() CGI::Application sub-class, in run mode 'redirect_test'.
# Expect HTTP redirect header + 'Hello World: redirect_test'.
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'redirect_test'}));

	response_like(
		$app,
		qr/^Status: 302/,
		qr/Hello World: redirect_test/,
		'TestApp, redirect_test'
	);
}


# run() CGI::Application sub-class, in run mode 'redirect_test'.
# Expect HTTP redirect header + 'Hello World: redirect_test'.
# ...just like the test above, but we pass QUERY in via a hashref.
{
	my $app = TestApp->new({
    QUERY => CGI->new({'test_rm' => 'redirect_test'})
  });

	response_like(
		$app,
		qr/^Status: 302/,
		qr/Hello World: redirect_test/,
		'TestApp, redirect_test'
	);
}

# run() CGI::Application sub-class, in run mode 'dump_text'.
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'dump_txt'}));

	response_like(
		$app,
		qr{^Content-type: text/html}i,
		qr/Query Environment/,
		'TestApp, dump_text'
	);
}


# run() CGI::Application sub-class, in run mode 'cookie_test'. 
# Expect HTTP header w/ cookie:
#	 'c_name' => 'c_value' + 'Hello World: cookie_test'.
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'cookie_test'}));

	response_like(
		$app,
		qr/^Set-Cookie: c_name=c_value/,
		qr/Hello World: cookie_test/,
		"TestApp, cookie test",
	);
}


# run() CGI::Application sub-class, in run mode 'tmpl_test'. 
# Expect HTTP header + 'Hello World: tmpl_test'.
{
	my $app = TestApp->new(TMPL_PATH=>'t/lib/templates/');
	$app->query(CGI->new({'test_rm' => 'tmpl_test'}));

	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/---->Hello World: tmpl_test<----/,
		"TestApp, tmpl_test",
	);
}


# run() CGI::Application sub-class, in run mode 'tmpl_badparam_test'.
# Expect HTTP header + 'Hello World: tmpl_badparam_test'.
{
	my $app = TestApp->new(TMPL_PATH=>'t/lib/templates/');
	$app->query(CGI->new({'test_rm' => 'tmpl_badparam_test'}));

	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/---->Hello World: tmpl_badparam_test<----/,
		"TestApp, tmpl_badparam_test",
	);
}


# Instantiate and call run_mode 'eval_test'.	Expect 'eval_test OK' in output.
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'eval_test'}));

	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/Hello World: eval_test OK/,
		"TestApp, eval_test",
	);
}

# Test to make sure cgiapp_init() was called in inherited class.
{
	my $app = TestApp2->new();
	my $init_state = $app->param('CGIAPP_INIT');
	ok(defined($init_state), "TestApp2's cgiapp_init ran");
	is($init_state, 'true', "TestApp2's cgiapp_init set the right value");
}


# Test to make sure mode_param() can contain subref
{
	my $app = TestApp3->new();
	$app->query(CGI->new({'go_to_mode' => 'subref_modeparam'}));

	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/Hello World: subref_modeparam OK/,
		"TestApp3, subref_modeparam",
	);
}

# Test to make sure that "false" (but >0 length) run modes are valid -- will
# not default to start_mode()
{
	my $app = TestApp3->new();
	$app->query(CGI->new({'go_to_mode' => '0'}));
	
	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/Hello World: zero_mode OK/,
		"TestApp3, 0 as run mode isn't start_mode",
	);
}


# A blank mode_param value isn't useful; we fall back to start_mode.
{
	my $app = TestApp3->new();
 	$app->query(CGI->new({'go_to_mode' => ''}));
 	
 	response_like(
 		$app,
 		qr{^Content-Type: text/html},
 		qr/Hello World: default_mode OK/,
 		"TestApp3, q() as run mode is start_mode",
 	);
}

# Test to make sure that undef run modes will default to start_mode()
{
	my $app = TestApp3->new();
	$app->query(CGI->new({'go_to_mode' => 'undef_rm'}));
	
	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/Hello World: default_mode OK/,
		"TestApp3, undef run mode (goes to start_mode)",
	);
}

# Test run modes returning scalar-refs instead of scalars
{
	my $app = TestApp4->new(QUERY=>CGI->new(""));
	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/Hello World: subref_test OK/,
		"run modes can return scalar references",
	);
}


# Test "AUTOLOAD" run mode
{
	my $app = TestApp4->new();
	$app->query(CGI->new({'rm' => 'undefined_mode'}));

	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/Hello World: undefined_mode OK/,
		"AUTOLOAD run mode",
	);
}


# what if there is no AUTOLOAD?
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'undefined_mode'}));

  my $output = eval { $app->run };
  like($@, qr/No such run mode/, "no runmode + no autoload = exception");
}


# Can we incrementally add run modes?
# XXX: I don't see how this code tests that question. -- rjbs, 2006-06-30
{
	my $app;
	my $output;

	# Mode: BasicTest
	$app = TestApp5->new();
	$app->query(CGI->new({'rm' => 'basic_test1'}));

	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/Hello World: basic_test1/,
		"force basic_test1",
	);

	# Mode: BasicTest2
	$app = TestApp5->new();
	$app->query(CGI->new({'rm' => 'basic_test2'}));
	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/Hello World: basic_test2/,
		"force basic_test2",
	);

	# Mode: BasicTest3
	$app = TestApp5->new();
	$app->query(CGI->new({'rm' => 'basic_test3'}));
	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/Hello World: basic_test3/,
		"force basic_test3",
	);
}


# Can we add params in batches?
{
	my $app = TestApp5->new(
		PARAMS => {
			P1 => 'one',
			P2 => 'two'
		}
	);

	# Do params set via new still get set?
	my @plist = sort $app->param();
	is_deeply(\@plist, ['P1', 'P2'], "Pn params set during initialization");

	my @params = (
		'', 'one', 'two', 'new three', 'four', 'new five', 'six', 'seven', 'eight'
	);

	is($app->param("P$_"), $params[$_], "P$_ of 2 correct") for 1..2;

	# Can we still augment params one at a time?
	$app->param('P3', 'three');
	@plist = sort $app->param();
	is_deeply(\@plist, ['P1', 'P2', 'P3'], 'added one param to list');
	is($app->param("P$_"), $params[$_], "P$_ of 2 correct again") for 1..2;
	is($app->param("P3"), 'three', "and new arg, P3, is also correct");

	# Does a list of pairs work?
	my $pt3val = $app->param(
		'P3' => 'new three',
		'P4' => 'four',
		'P5' => 'five'
	);
	@plist = sort $app->param();
	is_deeply(\@plist, ['P1', 'P2', 'P3', 'P4', 'P5'], "all five args set ok");
	is($app->param("P$_"), $params[$_], "P$_ of 4 correct") for 1..4;
	is($app->param("P5"), 'five', "P5 also correct");

	# XXX: Do we really want to test for this?  Maybe we want to change this
	# behavior, on which hopefully nothing but this test depends...
	# -- rjbs, 2006-06-30
	ok(not(defined($pt3val)), "multiple param setting returns undef (for now)");


	# What about a hash-ref?	(Should return undef)
	my $pt4val = $app->param({
		'P5' => 'new five',
		'P6' => 'six',
		'P7' => 'seven',
	});
	@plist = sort $app->param();
	is_deeply(\@plist, ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7'], "7 params ok");
	is($app->param("P$_"), $params[$_], "P$_ of 7 correct") for 1..7;
	ok(not(defined($pt4val)), "multiple param setting returns undef (for now)");

	# What about a simple pass-through?	(Should return param value)
	my $pt5val = $app->param('P8', 'eight');
	@plist = sort $app->param();
	is_deeply(\@plist, [qw(P1 P2 P3 P4 P5 P6 P7 P8)], "P1-8 all ok");
	is($app->param("P$_"), $params[$_], "P$_ of 8 correct") for 1..8;
	is($pt5val, 'eight', "value returned on setting P8 is correct");
}


# test undef param values
{
  my $app = TestApp->new();

  $app->param(foo => 10);

  is(
    $app->delete,
    undef,
    "we get undef when deleting unnamed param",
  );

  is($app->param('foo'), 10, q(and our real param is still ok));
}

# test setting header_props before header_type 
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'props_before_redirect_test'}));
	my $output = $app->run();

	like($output, qr/test: 1/i, "added test header before redirect");
	like($output, qr/Status: 302/, "and still redirected");
}

# testing setting header_props more than once
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'header_props_twice_nomerge'}));
	my $output = $app->run();

	like($output, qr/test: Updated/i, "added test header");
	unlike($output, qr/second-header: 1/, "no second-header header");
	unlike($output, qr/Test2:/, "no Test2 header, either");
}

# testing header_add with arrayref
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'header_add_arrayref_test'}));
	my $output = $app->run();

	like($output, qr/Set-Cookie: cookie1=header_add/, "arrayref test: cookie1");
	like($output, qr/Set-Cookie: cookie2=header_add/, "arrayref test: cookie2");
}

# make sure header_add does not clobber earlier headers
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'header_props_before_header_add'}));
	my $output = $app->run();

	like($output, qr/Set-Cookie: cookie1=header_props/, "header_props: cookie1");
	like($output, qr/Set-Cookie: cookie2=header_add/,   "header_add: cookie2");
}

# make sure header_add works after header_props is called
{
	my $app = TestApp->new();
	$app->query(CGI->new({'test_rm' => 'header_add_after_header_props'}));
	my $output = $app->run();

	like($output, qr/Set-Cookie: cookie2=header_add/, "header add after props");
}

# test use of TMPL_PATH without trailing slash
{
	my $app = TestApp->new(TMPL_PATH=>'t/lib/templates');
	$app->query(CGI->new({'test_rm' => 'tmpl_badparam_test'}));

	response_like(
		$app,
		qr{^Content-Type: text/html},
		qr/---->Hello World: tmpl_badparam_test<----/,
		"TMPL_PATH without trailing slash",
	);
}


# If called "too early" we get undef for current runmode.
{
  my $app = CGI::Application->new;

  eval { $app->run_modes('whatever') };

  like($@, qr/odd number/i, "croak on odd number of args to run_modes");
}


# If called "too early" we get undef for current runmode.
{
  my $app = CGI::Application->new;
  is($app->get_current_runmode, undef, "current runmode is undef before run");
  
  my $dump = $app->dump;
  like($dump, qr/^Current Run mode: ''\n/, "no current run mode in dump");
}


# test delete() method by first setting some params and then deleting them
{
	my $app = TestApp5->new();
	$app->param(
		P1 => 'one',
		P2 => 'two',
		P3 => 'three'
	);

	is_deeply(
		[ sort $app->param ],
		[ qw(P1 P2 P3) ],
		"we start with P1 P2 P3",
	);

	#a valid delete
	my $p2value = $app->delete('P2');
	my @params = sort $app->param();

	is_deeply(\@params, ['P1', 'P3'], "P2 deletes without incident");
	is($p2value, "two", "and deletion returns the deleted value");

	is($app->param('P1'), 'one', 'P1 still has the right value');

	ok(!defined($app->param('P2')), 'P2 is now undef');
	is_deeply(
		[ sort $app->param ],
		['P1', 'P3'],
		"asking for P2 didn't instantiate it",
	);

	is($app->param('P3'), 'three', 'P3 still has the right value');


	#an invalid delete
	my $result = $app->delete('P4');
	
	ok(!defined($result), "we get undef back when deleting nonexistant param");
	is($app->param('P1'), 'one', "and P1's value is unmolested");
	ok(!defined($app->param('P4')), "and the fake param doesn't get a value");
	is($app->param('P3'), 'three', "and P3 is unmolested too");
}

###

my $t27_ta_obj = CGI::Application->new(
	TMPL_PATH => [qw(t/lib/templates /some/other/test/path)]
);
my ($t1, $t2) = (0,0);
my $tmpl_path = $t27_ta_obj->tmpl_path();

ok((ref $tmpl_path eq 'ARRAY'), 'tmpl_path returns array ref');
is($tmpl_path->[0], 't/lib/templates', 'tmpl_path first element is correct');
is($tmpl_path->[1], '/some/other/test/path', 'tmpl_path second element is correct');

my $tmpl = $t27_ta_obj->load_tmpl('test.tmpl');
$tmpl_path = $tmpl->{options}->{path};

ok((ref $tmpl_path eq 'ARRAY'), 'tmpl_path from H::T obj returns array ref');
ok(($tmpl_path->[0] eq 't/lib/templates'), 'tmpl_path from H::T obj first element is correct');
ok(($tmpl_path->[1] eq '/some/other/test/path'), 'tmpl_path from H::T obj second element is correct');

# All done!
