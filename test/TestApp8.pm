# $Id: TestApp8.pm,v 1.1 2003/02/01 07:48:09 jesse Exp $

package TestApp8;

use strict;

use CGI::Application;
@TestApp8::ISA = qw(CGI::Application);


sub setup {
	my $self = shift;

	# Test array-ref mode
	$self->start_mode('testcgi1_mode');
	$self->run_modes([qw/
		testcgi1_mode
		testcgi2_mode
		testcgi3_mode
	/]);
}


####  Run-Mode Methods

sub testcgi1_mode {
	my $self = shift;

	my $output = "Hello World: testcgi1_mode OK";

	return \$output;
}


sub testcgi2_mode {
	my $self = shift;

	my $output = "Hello World: testcgi2_mode OK";

	return \$output;
}


sub testcgi3_mode {
	my $self = shift;

	my $output = "Hello World: testcgi3_mode OK";

	return \$output;
}


1;

