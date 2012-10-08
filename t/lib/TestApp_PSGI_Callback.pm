package TestApp_PSGI_Callback;
use base qw(CGI::Application);

sub setup {
    my $self = shift;
    $self->start_mode('callback');
    $self->mode_param('rm');
    $self->run_modes('callback' => 'callback');
}

sub callback {
    my $self = shift;

    $self->header_props(-type => 'text/plain');
    $self->psgi_streaming_callback(sub {
       my $writer = shift;
       foreach my $i (1..10) {
           #sleep 1;
           $writer->write("check $i: " . time . "\n");
		}
	});
	return undef;
}

1;
