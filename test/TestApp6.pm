# $Id: TestApp6.pm,v 1.2 2002/05/26 23:18:47 jesse Exp $

package TestApp6;

use strict;

use Data::Dumper;

use CGI::Application;
@TestApp6::ISA = qw(CGI::Application);


sub setup {
	my $self = shift;

	$self->start_mode('prerun_test');

	$self->run_modes(

		# Test to make sure cgiapp_prerun() works
		'prerun_test'      => \&prerun_test,

		# Test to make sure prerun_mode() works
		'prerun_mode_test' => \&prerun_mode_test,
		'new_prerun_mode_test' => \&new_prerun_mode_test,  

		# Test to make sure you can't do the wrong thing
		'illegal_prerun_mode' => \&illegal_prerun_mode,
	);

	# Test for failure if prerun_mode is called in setup()
	$self->prerun_mode('not_to_be_trifled_with') if ($ENV{PRERUN_IN_SETUP});
}


sub cgiapp_prerun {
	my $self = shift;
	my $rm = shift;

	$self->param('PRERUN_RUNMODE', $rm);

	if ($self->get_current_runmode() eq 'prerun_mode_test') {
		# Override the current run-mode
		$self->prerun_mode('new_prerun_mode_test');
	}

	print Dumper($self);
}




############################
####  RUN MODE METHODS  ####
############################

sub prerun_test {
	my $self = shift;

	my $output = "Hello World: prerun_test OK";

	return \$output;
}


sub prerun_mode_test {
	my $self = shift;

	my $output = "Hello World: prerun_mode_test OK";

	return \$output;
}


sub new_prerun_mode_test {
	my $self = shift;

	my $output = "Hello World: new_prerun_mode_test OK";

	return \$output;
}


sub illegal_prerun_mode {
	my $self = shift;

	# This should cause a fatal error
	$self->prerun_mode('nothing_special');

	# We should never get here
	my $output = "Hello World: illegal_prerun_mode OK";

	return \$output;
}



1;

