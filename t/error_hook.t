#!/usr/bin/perl

package ca_test;

use Test::More qw/no_plan/;

use base 'CGI::Application';

$ENV{CGI_APP_RETURN_ONLY} = 1;
my $app = ca_test->new();
$app->run_modes(
    start => sub { die "I'm dead." }
);
$app->error_mode('test_error_hook');
sub test_error_hook {
    my $self    = shift;
    my $err_msg = shift;
    return "msg was: $err_msg";
}

my $out = $app->run;

like($out, qr/msg was: I'm dead/, "death is returned as normal.");

{
    $app->error_mode('test_error_hook2');
    sub test_error_hook2 {
        my $self    = shift;
        my $err_msg = shift;
        is ($self->param('passing_error_msg'), $err_msg, "error callback worked");
        return "msg was: $err_msg";
    }

    $app->add_callback('error', sub {
        my ($self,$err_msg) = @_;
        $self->param('passing_error_msg',$err_msg);    

    });

    my $out = $app->run();
    like($out, qr/msg was: I'm dead/, "death is still returned as normal.");

}




