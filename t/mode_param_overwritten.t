# This is for a bug introduced in 4.02 where mode_param
# didn't work if it was set in a sub-class. 

package My::CA;
use base 'CGI::Application';

sub cgiapp_init {
    my $self = shift;
    $self->mode_param('mine');
}


package main;
use Test::More tests => 1;

{
    my $app = My::CA->new();
    is( $app->mode_param, 'mine', "setting mode_param in a sub-class works");
}

