
use strict;
use Test::More;
use Plack::Test;
use HTTP::Request::Common;
use HTTP::Response;
use HTTP::Message::PSGI;
use Try::Tiny;
use CGI::PSGI;

use PSGI::Application;

{
  my $app = PSGI::Application->new;

  $app->header_type('none');

  my $warn = '';
  local $SIG{__WARN__} = sub {
    $warn = shift;
  };
  $app->header_props(-type => 'banana/ripe');

  like(
    $warn,
    qr/header_type set to 'none'/,
    "warn if we set header while header type is none",
  );
}

{
  my $app = PSGI::Application->new;

  try { $app->header_props(123); }
  finally {
      my $err = shift;
      like(
          $err,
          qr/odd number/i,
          "croak on odd number of non-ref args to header_props",
      );

  };


  try { $app->header_add(123); }
  finally {
      my $err = shift;
      like(
          $err,
          qr/odd number/i,
          "croak on odd number of non-ref args to header_add",
      );
  };
}

test_psgi
    app => sub {
        my $env = shift;
        my $app = PSGI::Application->new( REQUEST => CGI::PSGI->new($env) );
        $app->header_props( -type => 'banana/ripe' );
        $app->header_add( -expires => '1d' );
        return $app->run;
    },
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/');
        like(
          $res->header('Content-Type'),
          qr{banana/ripe},
          "headed added via hashref arg to header_props",
        );

        like(
          $res->as_string,
          qr{^Expires: }im,
          "headed added via hashref arg to header_add",
        );
    };


done_testing();
