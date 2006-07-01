package TestApp10;
use strict;
use CGI::Application;
@TestApp10::ISA = qw(CGI::Application);


sub setup {
    my $self = shift;
    $self->run_modes({ AUTOLOAD => "handler" });
    $self->start_mode( 0 );
}


sub handler {
    my $self = shift;

    my $rm = $self->get_current_runmode();

    if ($rm eq "0") {

        return "Success!";

    } else {

        return "Failure!";

    }
}

1;
