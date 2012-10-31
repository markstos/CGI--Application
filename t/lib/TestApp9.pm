package TestApp9;
use Any::Moose;
extends 'PSGI::Application';

sub setup {
    my $self = shift;
    $self->run_modes([qw(
                         noheader
                         postrun_body
                         postrun_header
                        )]);
}


sub postrun {
    my $self = shift;
    my $output_ref = shift;


    my $rm = $self->get_current_runmode();

    warn "in postrun: $rm";

    if ($rm eq 'postrun_body') {
        $$output_ref .= "\npostrun was here";
    } 
    elsif ($rm eq 'postrun_header') {
        warn "rm eq postrun headers!";
        $self->header_type('redirect');
        $self->header_props(-url=>'postrun.html');
    }
}


sub noheader {
    my $self = shift;
    $self->header_type('none');
    return "Hello world: noheader";
}


sub postrun_body {
    return "Hello world: postrun_body";
}


sub postrun_header {
    return "Hello world: postrun_header";
}


1;
