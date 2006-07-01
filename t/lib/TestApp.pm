
package TestApp;

use strict;


use CGI::Application;
@TestApp::ISA = qw(CGI::Application);


sub setup {
	my $self = shift;

	$self->start_mode('basic_test');

	$self->mode_param('test_rm');

	$self->run_modes(
		'basic_test'		         => \&basic_test,
		'redirect_test'		         => \&redirect_test,
		'cookie_test'		         => \&cookie_test,
		'tmpl_test'		             => \&tmpl_test,
		'tmpl_badparam_test'	     => \&tmpl_badparam_test,
    'props_before_redirect_test' => \&props_before_redirect_test,
    'header_props_twice_nomerge'    => \&header_props_twice_nomerge,
 		'header_add_arrayref_test'		=> \&header_add_arrayref_test,
 		'header_props_before_header_add'		=> \&header_props_before_header_add,
 		'header_add_after_header_props'		=> \&header_add_after_header_props,

    'dump_txt'    => 'dump',
		'eval_test'		=> 'eval_test',
	);

	$self->param('last_orm', 'setup');
}


sub teardown {
	my $self = shift;

	$self->param('last_orm', 'teardown');
}


sub cgiapp_init {
	my $self = shift;
	$self->param('CGIAPP_INIT', 'true');
}



############################
####  RUN MODE METHODS  ####
############################

sub basic_test {
	my $self = shift;

	return "Hello World: basic_test";
}


sub redirect_test {
	my $self = shift;

	$self->header_type('redirect');
	$self->header_props(
		-url => 'http://www.erlbaum.net/'
	);

	return "Hello World: redirect_test";
}


sub cookie_test {
	my $self = shift;
	my $q = $self->query();

	my $cookie = $q->cookie(
		-name => 'c_name',
		-value => 'c_value',
		-path => '/cookie_path_123',
		-domain => 'some.cookie.dom',
		-expires=>'-1y'
	);
	$self->header_props(
		-cookie => $cookie		
	);

	return "Hello World: cookie_test";
}


sub tmpl_test {
	my $self = shift;

	my $t = $self->load_tmpl('test.tmpl');
	$t->param('ping', 'Hello World: tmpl_test');
	
	return $t->output();
}


sub tmpl_badparam_test {
	my $self = shift;

	my $t = $self->load_tmpl('test.tmpl', die_on_bad_params => 0);

	# This tests to see if die_on_bad_params was really turned off!
	$t->param('some_non_existent_tmpl_var', 123);

	$t->param('ping', 'Hello World: tmpl_badparam_test');
	
	return $t->output();
}


sub eval_test {
	my $self = shift;

	die ("No cgi-app object '$self'") unless (ref($self));

	return "Hello World: eval_test OK";
}

sub props_before_redirect_test {
    my $self = shift;

    $self->header_props(
        '-Test'  => 1,
        '-url'   => 'othersite.com',
    );
    $self->header_type('redirect');
	return;
}

sub header_props_twice_nomerge {
    my $self = shift;
    $self->header_props(
        '-Test'  => 1,
        '-Second-header' => 1,
    );

    $self->header_props(
        '-Test'          => 'Updated',
    );
    return 1;
}

sub header_add_arrayref_test {
    my $self = shift;
    $self->header_add(-cookie => ['cookie1=header_add; path=/', 'cookie2=header_add; path=/']);

    return 1;
}

sub header_props_before_header_add {
    my $self = shift;
    $self->header_props(-cookie => 'cookie1=header_props; path=/');
    $self->header_add(-cookie => ['cookie2=header_add; path=/']);

    return 1;
}

sub header_props_after_header_add {
    my $self = shift;
    $self->header_add(-cookie => 'cookie1=header_add; path=/');
    $self->header_props(-cookie => 'cookie2=header_props; path=/');

    return 1;
}

sub header_add_after_header_props {
    my $self = shift;
    $self->header_props(-cookie => 'cookie1=header_props; path=/');
    $self->header_add(-cookie => 'cookie2=header_add; path=/');

    return 1;
}

1;

