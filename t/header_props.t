
use strict;
use Test::More tests => 9;

BEGIN{use_ok('CGI::Application');}

$ENV{CGI_APP_RETURN_ONLY} = 1;

{
  my $app = CGI::Application->new;

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
  my $app = CGI::Application->new;

  eval { $app->header_props(123); };

  like(
    $@,
    qr/odd number/i,
    "croak on odd number of non-ref args to header_props",
  );

  eval { $app->header_add(123); };

  like(
    $@,
    qr/odd number/i,
    "croak on odd number of non-ref args to header_add",
  );
}

{
  my $app = CGI::Application->new;

  $app->header_props({ -type => 'banana/ripe' });
  $app->header_add({ -expires => '1d' });

  like(
    $app->run,
    qr{Content-type: banana/ripe}i,
    "headed added via hashref arg to header_props",
  );

  like(
    $app->run,
    qr{^Expires: }im,
    "headed added via hashref arg to header_add",
  );
}

{
  my $app = CGI::Application->new;

  $app->header_props({ -type => 'banana/ripe' });

  like(
    $app->run,
    qr{Content-type: banana/ripe}i,
    "headed added via hashref arg to header_props",
  );

  $app->header_props();

  like(
    $app->run,
    qr{Content-type: banana/ripe}i,
    "Calling with no args is safe",
  );

  $app->header_props({});

  unlike(
    $app->run,
    qr{Content-type: banana/ripe}i,
    "Calling with an empty hashref clobbers existing data",
  );

}

