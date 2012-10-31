#!/usr/bin/perl

package ca_test;
use Any::Moose;
extends 'PSGI::Application';
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use CGI::PSGI;

test_psgi
    app => sub { 
        my $env = shift;
        my $app = ca_test->new(REQUEST => CGI::PSGI->new($env) );
        $app->run_modes(
            start => sub { die "I'm dead." }
        );
        $app->error_mode('test_error_hook');
        sub test_error_hook {
            my $self    = shift;
            my $err_msg = shift;
            return "msg was: $err_msg";
        }

        return $app->run;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/');
        like($res->content, qr/msg was: I'm dead/, "death is returned as normal.");
    };

test_psgi
    app => sub { 
        my $env = shift;
        my $app = ca_test->new(REQUEST => CGI::PSGI->new($env) );
        $app->run_modes(
            start => sub { die "I'm dead." }
        );
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

        return $app->run;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/');
        like($res->content, qr/msg was: I'm dead/, "death is returned as normal.");
    };



done_testing();

