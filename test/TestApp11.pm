package TestApp11;
use strict;
use CGI::Application;
@TestApp11::ISA = qw(CGI::Application);

# Prevent output to STDOUT
$ENV{CGI_APP_RETURN_ONLY} = 1;

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

    return "Success!";
}

1;
