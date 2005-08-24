
package My::App;

use Test::More qw/no_plan/;

use  base 'CGI::Application';

my $obj = CGI::Application->new(TMPL_PATH => [qw(test/templates)]);

$obj->{__CURRENT_TMPL_EXTENSION} = '.tmpl';
$obj->{__CURRENT_RUNMODE} = 'test';

{
    my $tmpl = $obj->load_tmpl(undef);
    like ($tmpl->output, qr/---/, "automatic defualt template extension works");
}

{
    my $tmpl = $obj->load_tmpl;
    like ($tmpl->output, qr/---/, "automatic defualt template extension works");
}



