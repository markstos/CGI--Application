# $Id: TestApp.pm,v 1.1 2000/07/07 04:42:21 jesse Exp $

package TestApp;

use strict;

use lib '../';
use base 'CGI::Application';


sub setup {
	my $self = shift;
	$self->run_modes(
		'basic_test'    => \&basic_test,
		'redirect_test' => \&redirect_test,
		'cookie_test'   => \&cookie_test,
		'dump_test'     => \&dump_test,
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

	return "Hello World";
}


sub redirect_test {
	my $self = shift;

	$self->header_type('redirect');
	$self->header_props(
		-url => 'http://www.vm.com/'
	);

	return "Hello World";
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

	return "Hello World";
}


sub dump_test {
	my $self = shift;

	my $output = $self->dump_html();
	print STDERR $self->dump();

	return $output;
}


sub tmpl_test {
	my $self = shift;
}


1;

