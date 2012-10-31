
use strict;
use Test::More tests => 5;

BEGIN{use_ok('PSGI::Application');}

my $app = PSGI::Application->new();
isa_ok($app, 'PSGI::Application');

$app->param(foo => 1);

is($app->param('foo'), 1, "successfully set a param");

my $copy = $app->new;

isa_ok($copy, 'PSGI::Application', 'a copy of the object');

is($copy->param('foo'), undef, "...no data is actually copied; new isn't copy");
