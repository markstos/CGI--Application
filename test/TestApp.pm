# $Id: TestApp.pm,v 1.2 2000/07/11 03:15:07 jesse Exp $

package TestApp;

use strict;

use base 'CGI::Application';


sub setup {
	my $self = shift;

	$self->start_mode('basic_test');

	$self->mode_param('test_rm');

	$self->run_modes(
		'basic_test'    => \&basic_test,
		'redirect_test' => \&redirect_test,
		'cookie_test'   => \&cookie_test,
		'tmpl_test'     => \&tmpl_test,
	);

	$self->param('last_orm', 'setup');
}


sub teardown {
	my $self = shift;

	$self->param('last_orm', 'teardown');
}


sub basic_test {
	my $self = shift;

	return "Hello World: basic_test";
}


sub redirect_test {
	my $self = shift;

	$self->header_type('redirect');
	$self->header_props(
		-url => 'http://www.vm.com/'
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


1;

