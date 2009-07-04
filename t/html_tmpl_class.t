use Test::More 'no_plan';

use CGI::Application;

# Prevent output to STDOUT
$ENV{CGI_APP_RETURN_ONLY} = 1;

my $app = CGI::Application->new;

is($app->html_tmpl_class, 'HTML::Template', 'html_tmpl_class defaults to HTML::Template');
is($app->html_tmpl_class('HTML::Template::Dumper'), 'HTML::Template::Dumper', 'setting a class returns the new class');
is($app->html_tmpl_class, 'HTML::Template::Dumper', '...and is retained');

