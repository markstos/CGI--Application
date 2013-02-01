
use Test::More;
use CGI::Application;

eval { require CGI::PSGI; };
# XXX, really, we need CGI::PSGI 0.09 or later.
if ($@) {
   plan 'skip_all' => 'CGI::PSGI is not available';
}
else {
  plan 'no_plan';
}


# Set up a CGI environment
my $env;
$env->{REQUEST_METHOD}  = 'GET';
$env->{QUERY_STRING}    = 'game=chess&game=checkers&weather=dull';
$env->{PATH_INFO}       = '/somewhere/else';
$env->{PATH_TRANSLATED} = '/usr/local/somewhere/else';
$env->{SCRIPT_NAME}     = '/cgi-bin/foo.cgi';
$env->{SERVER_PROTOCOL} = 'HTTP/1.0';
$env->{SERVER_PORT}     = 8080;
$env->{SERVER_NAME}     = 'the.good.ship.lollypop.com';
$env->{REQUEST_URI}     = "$env->{SCRIPT_NAME}$env->{PATH_INFO}?$env->{QUERY_STRING}";
$env->{HTTP_LOVE}       = 'true';

package TestApp;
use base 'CGI::Application';
sub setup {
    my $self = shift;
    $self->run_modes(
        start => sub { $self->query->http('Love') },
    );
}

package main;

my $app = TestApp->psgi_app;

my %env1 = %{$env};
my $res1 = $app->( \%env1 );
is_deeply $res1, [
    '200',
    [ 'Content-Type' => 'text/html; charset=ISO-8859-1' ],
    [ 'true' ],
],
"psgi_app: reality check basic response";

my %env2 = ( %{$env}, HTTP_LOVE => 'false' );
my $res2 = $app->( \%env2 );
is $res2->[2]->[0], 'false', 'psgi_app: QUERY should be updated';
