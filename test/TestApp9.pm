package TestApp9;
use strict;
use CGI::Application;
@TestApp9::ISA = qw(CGI::Application);


sub setup {
    my $self = shift;
    $self->run_modes([qw(
                         noheader
                         postrun_body
                         postrun_header
                        )]);
}


sub cgiapp_postrun {
    my $self = shift;
    my $output_ref = shift;

    my $rm = $self->get_current_runmode();

    if ($rm eq "postrun_body") {

        $$output_ref .= "\npostrun was here";

    } elsif ($rm eq "postrun_header") {

        $self->header_type("redirect");
        $self->header_props(-url=>"postrun.html");

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
