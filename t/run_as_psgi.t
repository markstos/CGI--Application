
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
        start => sub { 'Hello World' },
    );
}

package main;

my $app = TestApp->new( QUERY => CGI::PSGI->new($env) );

my $response = $app->run_as_psgi;

is_deeply $response, [
    '200',
    [ 'Content-Type' => 'text/html; charset=ISO-8859-1' ],
    [ 'Hello World' ],
],
"run_as_psgi: reality check basic response";
