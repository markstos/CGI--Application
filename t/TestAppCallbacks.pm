package TestAppCallbacks;

use strict;

use CGI::Application;
@TestAppCallbacks::ISA = qw(CGI::Application);

sub cgiapp_prerun {
    my $self = shift;
    delete $ENV{'PRERUN_TEST'};
    $self->new_hook('test_hook');
    $self->add_callback('test_hook', \&callback);
    $self->call_hook('test_hook');
}

sub cgiapp_postrun {
    my $self = shift;
    delete $ENV{'POSTRUN_TEST'};
}

sub teardown {
    my $self = shift;
    delete $ENV{'TEARDOWN_TEST'};
}

sub callback {
    delete $ENV{'CALLBACK_TEST'};
}

sub setup {
    my $self = shift;
    $self->start_mode('test_mode');
    $self->run_modes(test_mode => 'test_mode' );
}

sub test_mode {
    my $self = shift;

    return "test_mode return value";
}


1;
