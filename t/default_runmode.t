use strict;
use warnings;

use Test::More tests => 1;

$ENV{'CGI_APP_RETURN_ONLY'} = 1; # don't print

{
    package WithStartIssue;

    use base 'CGI::Application';

    # register custom "start" run mode.
    # this is what CAP::AutoRunmode and CAP::RunmodeDeclare do.
    __PACKAGE__->add_callback('init' => sub {
        shift->run_modes('start' => 'my_start');
        }
    );

    sub my_start { return 'my start' }

    # don't output a header
    sub cgiapp_prerun {
        shift->header_type('none');
    }
}

my $issue = WithStartIssue->new;
my $out = $issue->run;

is $out, 'my start';
