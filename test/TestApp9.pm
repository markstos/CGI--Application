package TestApp9;
use strict;
use CGI::Application;
@TestApp9::ISA = qw(CGI::Application);


sub setup {
    my $self = shift;
    $self->run_modes([qw/
                      noheader
                      /]);
}


sub noheader {
    my $self = shift;
    $self->header_type('none');
    return "Hello world: noheader";
}


1;
