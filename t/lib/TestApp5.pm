package TestApp5;
use Any::Moose;
extends 'PSGI::Application';

sub setup {
    my $self = shift;

    $self->start_mode('nomode');

    $self->mode_param('rm');

    $self->run_modes(
        'basic_test1'       => 'basic_test1',
        'basic_test2'       => 'badmode',
    );

    # Add more run modes.  All should work now
    $self->run_modes(
        'basic_test2'       => 'basic_test2',
        'basic_test3'       => 'basic_test3',
    );
}

sub basic_test1 { 'Hello World: basic_test1' }
sub basic_test2 { 'Hello World: basic_test2' }
sub basic_test3 { 'Hello World: basic_test3' }

1;

