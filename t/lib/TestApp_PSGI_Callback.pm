package TestApp_PSGI_Callback;
use base qw(CGI::Application);

sub setup {
    my $self = shift;
    $self->start_mode('test');
    $self->mode_param('rm');
	$self->run_modes([qw/test file_handle callback_subref callback_explicit/])
}

sub test {
	return "test";
}

sub file_handle {
    my $self = shift;

	my $test_file = 't/test_file_to_stream.txt';

    open my $fh, "<", $test_file or die "OOPS! $!";

    $self->header_props(-type => 'text/plain');

	return $fh;
}

sub callback_subref {
    my $self = shift;

    $self->header_props(-type => 'text/plain');
    return sub {
       my $writer = shift;
       foreach my $i (1..10) {
           #sleep 1;
           $writer->write("check $i: " . time . "\n");
		}
	};
}

sub callback_explicit {
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
