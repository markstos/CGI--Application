# $Id: TestApp6.pm,v 1.1 2002/05/06 03:10:43 jesse Exp $

package TestApp6;

use strict;


use CGI::Application;
@TestApp6::ISA = qw(CGI::Application);


sub setup {
	my $self = shift;

	$self->start_mode('prerun_test');

	$self->run_modes(
		'prerun_test' => \&prerun_test,
	);
}


sub cgiapp_prerun {
	my $self = shift;
	my $rm = shift;

	$self->param('PRERUN_RUNMODE', $rm);
}




############################
####  RUN MODE METHODS  ####
############################

sub prerun_test {
	my $self = shift;

	my $output = "Hello World: prerun_test OK";

	return \$output;
}



1;

