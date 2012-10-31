use strict;
use warnings;

use Test::More;
use Plack::Test;
use HTTP::Request::Common;

{
    package WithStartIssue;
    use Any::Moose;
    extends 'PSGI::Application';

    # register custom "start" run mode.
    # this is what CAP::AutoRunmode and CAP::RunmodeDeclare do.
    __PACKAGE__->add_callback('init' => sub {
        shift->run_modes('start' => 'my_start');
        }
    );

    sub my_start { return 'my start' }

    # don't output a header
    sub prerun {
        shift->header_type('none');
    }
}

test_psgi
    app => WithStartIssue->psgi_app,
    client => sub {
        my $cb = shift;
        my $res = $cb->(GET '/');
        is($res->content,'my start');
    };

done_testing();
