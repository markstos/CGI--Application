# $Id: TestApp4.pm,v 1.1 2001/06/25 03:01:19 jesse Exp $

package TestApp4;

use strict;


use CGI::Application;
@TestApp4::ISA = qw(CGI::Application);


sub setup {
	my $self = shift;

	$self->start_mode('subref_test');

	$self->run_modes(
		'subref_test' => \&subref_test,
		'AUTOLOAD' => \&autoload_meth
	);
}




############################
####  RUN MODE METHODS  ####
############################

sub subref_test {
	my $self = shift;

	my $output = "Hello World: subref_test OK";

	return \$output;
}


sub autoload_meth {
	my $self = shift;
	my $real_rm = shift;

	return "Hello World: $real_rm OK";
}


1;

