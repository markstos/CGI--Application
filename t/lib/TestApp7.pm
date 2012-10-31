
package TestApp7;
use Any::Moose;
extends 'PSGI::Application';

sub setup {
	my $self = shift;

	$self->run_modes(
		testcgi_mode => 'testcgi_mode'
	);
}

sub get_request {
	my $self = shift;

	require TestCGI;
	my $q = TestCGI->new({});

	return $q;
}


####  Run Mode Methods

sub testcgi_mode {
	my $self = shift;

	my $output = "Hello World: testcgi_mode OK";

	return \$output;
}


1;

