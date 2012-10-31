package TestApp14;
use Any::Moose;
extends 'PSGI::Application';

sub setup {
    my $self = shift;
    $self->run_modes([qw/ start /]);
    #$self->tmpl_path('t/lib/templates');
}

sub start {
    my $self = shift;

    #my $t = $self->load_tmpl('test.tmpl');
    $t->param(ping => $self->req->param('message'));

    return $t->output();
}

1;
