
use strict;
use Test::More tests => 5;

BEGIN{use_ok('CGI::Application');}

my $app = CGI::Application->new();
isa_ok($app, 'CGI::Application');

$app->param(foo => 1);

is($app->param('foo'), 1, "successfully set a param");

my $copy = $app->new;

isa_ok($copy, 'CGI::Application', 'a copy of the object');

is($copy->param('foo'), undef, "...no data is actually copied; new isn't copy");
