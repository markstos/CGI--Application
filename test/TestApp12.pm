package TestApp12;
use strict;
use CGI::Application;
@TestApp12::ISA = qw(CGI::Application);


sub setup {
    my $self = shift;
    $self->run_modes( mode1 => "mode1" );
    $self->start_mode( 'mode1' );
    $self->error_mode( 'error' );
}


sub mode1 {
    my $self = shift;

    die "mode1 failed!\n";
}

sub error {
    my $self = shift;

    die "Oops!\n";
}

1;
