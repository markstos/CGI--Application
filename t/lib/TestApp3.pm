
package TestApp3;
use Any::Moose;
extends 'PSGI::Application';

sub setup {
	my $self = shift;

	$self->start_mode('default_mode');

	$self->mode_param(\&set_up_runmode);

	$self->run_modes(
		'subref_modeparam'	=> \&subref_modeparam_meth,
		'0'			=> \&zero_mode,
		''			=> \&blank_mode,
		'default_mode'		=> \&default_mode_meth,
	);
}


sub set_up_runmode {
	my $self = shift;

	my $q = $self->req();
	my $rm = $q->param('go_to_mode');

	return undef if ($rm eq 'undef_rm');

	return $rm;
}



############################
####  RUN MODE METHODS  ####
############################

sub subref_modeparam_meth { 'Hello World: subref_modeparam OK' } 
sub blank_mode            { 'Hello World: blank_mode OK'       } 
sub zero_mode             { 'Hello World: zero_mode OK'        } 
sub default_mode_meth     { 'Hello World: default_mode OK'     } 

1;

