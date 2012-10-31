
use strict;
use Test::More;
use PSGI::Application;
use Plack::Test;
use HTTP::Response;
use HTTP::Request::Common;
use HTTP::Message::PSGI;
use CGI::PSGI;
use Try::Tiny;

# bring in testing hierarchy
use lib 't/lib';
use TestApp;
use TestApp2;
use TestApp3;
use TestApp4;
use TestApp5;
use Carp 'verbose';

sub response_like {
    my ($app, $header_re, $body_re, $comment) = @_;

     my $res = HTTP::Response->from_psgi( $app->()->run );

    like($res->as_string, $header_re, "$comment (header match)");
    like($res->as_string, $body_re,   "$comment (body match)");
}

# Instantiate PSGI::Application
# run() PSGI::Application object.   Expect header + Hello World
test_psgi
    app => sub {
        my $env = shift;
        my $p = PSGI::Application->new( REQUEST => CGI::PSGI->new($env) );
        isa_ok($p, 'PSGI::Application');
        return $p->run;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/');
        like($res->content, qr/Hello World/i, 'base class response');
    };

# Instantiate PSGI::Application sub-class.
# run() PSGI::Application sub-class. 
# Expect HTTP header + 'Hello World: basic_test'.
{
    my $app = sub {
        my $env = shift;
        my $p = TestApp->new( REQUEST => CGI::PSGI->new($env) );
        isa_ok($p, 'TestApp');
        isa_ok('TestApp', 'PSGI::Application');
        return $p;
    };

    response_like(
        $app,
        qr{Content-Type: text/html},
        qr/Hello World: basic_test/,
        'TestApp, blank query',
    );
}


# Non-hash references are invalid for PARAMS.
{
   eval { TestApp->new(PARAMS => [] ) };
   like($@, qr/Validation failed/i, "PARAMS must be a hashref!");
}

# run() PSGI::Application sub-class, in run mode 'redirect_test'.
# Expect HTTP redirect header + 'Hello World: redirect_test'.
test_psgi
    app => TestApp->psgi_app,
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/?test_rm=redirect_test');
        is $res->code, 302, "response code is 302, for a redirect";
        like $res->content, qr/Hello World: redirect_test/, 'TestApp, redirect_test';
    };


# run() PSGI::Application sub-class, in run mode 'redirect_test'.
# Expect HTTP redirect header + 'Hello World: redirect_test'.
# ...just like the test above, but we pass QUERY in via a hashref.
test_psgi
    app => sub {
        my $env = shift;
        my $app = TestApp->new({ REQUEST => CGI::PSGI->new($env) });
        return $app->run;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/?test_rm=redirect_test');
        is $res->code, 302, "response code is 302, for a redirect";
        like $res->content, qr/Hello World: redirect_test/, 'TestApp, redirect_test';
    };


# run() PSGI::Application sub-class, in run mode 'cookie_test'. 
# Expect HTTP header w/ cookie:
#    'c_name' => 'c_value' + 'Hello World: cookie_test'.
test_psgi
    app => TestApp->psgi_app,
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/?test_rm=cookie_test');
        is $res->code, 200;
        like $res->header('Set-Cookie'), qr/c_name=c_value/;
        like $res->content, qr/Hello World: cookie_test/;
    };

test_psgi
    app => TestApp->psgi_app,
    client => sub {
        # Instantiate and call run_mode 'eval_test'.    Expect 'eval_test OK' in output.
        my $cb = shift;
        my $res = $cb->(GET '/?test_rm=eval_test');
        like $res->header('Content-Type'), qr{text/html};
        like $res->content, qr/Hello World: eval_test OK/;
    };


# Test to make sure init() was called in inherited class.
{
    my $app = TestApp2->new();
    my $init_state = $app->param('CGIAPP_INIT');
    ok(defined($init_state), "TestApp2's init ran");
    is($init_state, 'true', "TestApp2's init set the right value");
}


test_psgi
    app => TestApp3->psgi_app,
    client => sub {
        my $cb = shift;

        # Test to make sure mode_param() can contain subref
        my $res = $cb->(GET '/?go_to_mode=subref_modeparam');
        is $res->code, 200;
        like $res->content, qr/Hello World: subref_modeparam OK/, "TestApp3, subref_modeparam";
    };

test_psgi
    app => TestApp3->psgi_app,
    client => sub {
        # Test to make sure that "false" (but >0 length) run modes are valid -- will
        # not default to start_mode()
        my $cb = shift;
        my $res = $cb->(GET '/?go_to_mode=0');
        is $res->code, 200;
        like $res->content, qr/Hello World: zero_mode OK/, "TestApp3, 0 as run mode isn't start_mode";
    };

test_psgi
    app => TestApp3->psgi_app,
    client => sub {
        # A blank mode_param value isn't useful; we fall back to start_mode.
        my $cb = shift;
        my $res = $cb->(GET '/?go_to_mode=');
        is $res->code, 200;
        like $res->content, qr/Hello World: default_mode OK/, "TestApp3, q() as run mode is start_mode";
    };

test_psgi
    app => TestApp3->psgi_app,
    client => sub {
        # Test to make sure that undef run modes will default to start_mode()
        my $cb = shift;
        my $res = $cb->(GET '/?go_to_mode=undef_rm');
        is $res->code, 200;
        like $res->content, qr/Hello World: default_mode OK/, "TestApp3, undef run mode (goes to start_mode)",
    };

test_psgi
    app => TestApp4->psgi_app,
    client => sub {
        my $cb = shift;

        # Test run modes returning scalar-refs instead of scalars
        my $res = $cb->(GET '/');
        is $res->code, 200;
        like $res->content, qr/Hello World: subref_test OK/, "run modes can return scalar references";
    };

test_psgi
    app => TestApp4->psgi_app,
    client => sub {
        my $cb = shift;

        # Test "AUTOLOAD" run mode
        my $res = $cb->(GET '/?rm=undefined_mode');
        is $res->code, 200;
        like $res->content, qr/Hello World: undefined_mode OK/, "AUTOLOAD run mode";
    };

# what if there is no AUTOLOAD?
test_psgi
    app => TestApp->psgi_app,
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/?test_rm=undefined_mode');
        is $res->code, 500;
        like $res->content, qr/No such run mode/, "no runmode + no autoload = exception";
    };
test_psgi
    app => TestApp5->psgi_app,
    client => sub {
        my $cb = shift;

        # Can we incrementally add run modes?
        # XXX: I don't see how this code tests that question. -- rjbs, 2006-06-30
        my $res = $cb->(GET '/?rm=basic_test1');
        is $res->code, 200;
        like $res->content, qr/Hello World: basic_test1/, "force basic_test1";
    };
test_psgi
    app => TestApp5->psgi_app,
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/?rm=basic_test2');
        is $res->code, 200;
        like $res->content, qr/Hello World: basic_test2/, "force basic_test2";
    };
test_psgi
    app => TestApp5->psgi_app,
    client => sub {
        my $cb = shift;

        my $res = $cb->(GET '/?rm=basic_test3');
        is $res->code, 200;
        like $res->content, qr/Hello World: basic_test3/, "force basic_test3";
    };


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


    # What about a hash-ref?    (Should return undef)
    my $pt4val = $app->param({
        'P5' => 'new five',
        'P6' => 'six',
        'P7' => 'seven',
    });
    @plist = sort $app->param();
    is_deeply(\@plist, ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7'], "7 params ok");
    is($app->param("P$_"), $params[$_], "P$_ of 7 correct") for 1..7;
    ok(not(defined($pt4val)), "multiple param setting returns undef (for now)");

    # What about a simple pass-through? (Should return param value)
    my $pt5val = $app->param('P8', 'eight');
    @plist = sort $app->param();
    is_deeply(\@plist, [qw(P1 P2 P3 P4 P5 P6 P7 P8)], "P1-8 all ok");
    is($app->param("P$_"), $params[$_], "P$_ of 8 correct") for 1..8;
    is($pt5val, 'eight', "value returned on setting P8 is correct");
}

test_psgi
   app => TestApp->psgi_app,
   client => sub {
       my $cb = shift;

       # test setting header_props before header_type 
       my $res = $cb->(GET '/?test_rm=props_before_redirect_test');
       is $res->code, 302, "redirected";
       is $res->header('Test'), 1, 'added test header before redirect';
    };
test_psgi
    app => TestApp->psgi_app,
    client => sub {
       my $cb = shift;

       # testing setting header_props more than once
       my $res = $cb->(GET '/?test_rm=header_props_twice_nomerge');
       is $res->header('Test'), 'Updated', 'added test header';
       unlike $res->as_string, qr/second-header: 1/, "no second-header header";
       unlike $res->as_string, qr/Test2:/, "no Test2 header, either";
    };
test_psgi
    app => TestApp->psgi_app,
    client => sub {
      my $cb = shift;

      # testing header_add with arrayref
      my $res = $cb->(GET '/?test_rm=header_add_arrayref_test');
      like $res->as_string, qr/Set-Cookie: cookie1=header_add/, "arrayref test: cookie1";
      like $res->as_string, qr/Set-Cookie: cookie2=header_add/, "arrayref test: cookie2";
    };
test_psgi
    app => TestApp->psgi_app,
    client => sub {
      my $cb = shift;

      # make sure header_add does not clobber earlier headers
      my $res = $cb->(GET '/?test_rm=header_props_before_header_add');
      like $res->as_string, qr/Set-Cookie: cookie1=header_props/, "header_props: cookie1";
      like $res->as_string, qr/Set-Cookie: cookie2=header_add/,   "header_add: cookie2";
    };
test_psgi
    app => TestApp->psgi_app,
    client => sub {
      my $cb = shift;

      # make sure header_add works after header_props is called
      my $res = $cb->(GET '?test_rm=header_add_after_header_props');
      like $res->as_string, qr/Set-Cookie: cookie2=header_add/, "header add after props" ;
   };


# If called "too early" we get undef for current runmode.
{
  my $app = PSGI::Application->new;
  eval { $app->run_modes('whatever') };
  like($@, qr/odd number/i, "croak on odd number of args to run_modes");
}


# If called "too early" we get undef for current runmode.
{
  my $app = PSGI::Application->new;
  is($app->get_current_runmode, undef, "current runmode is undef before run");
}

done_testing();


