package TestApp4;
use Any::Moose;
extends 'PSGI::Application';

sub setup {
    my $self = shift;

    $self->start_mode('subref_test');
    $self->run_modes(
        'subref_test' => \&subref_test,
        'AUTOLOAD' => \&autoload_meth
    );
}


sub subref_test { \"Hello World: subref_test OK" };

sub autoload_meth {
    my $self = shift;
    my $real_rm = shift;
    return "Hello World: $real_rm OK";
}


1;

