#!/usr/bin/perl

use Test::More tests => 5;

use CGI::Application;

$ENV{CGI_APP_RETURN_ONLY} = 1;
my $app = CGI::Application->new();
my $out = $app->run;

like($out, qr/start/, "normal app output contains start");
unlike($out, qr/load_tmpl_hook/, "normal app output doesn't contain load_tmpl_hook");

 {
     $app->add_callback('load_tmpl', sub {
         my ($self,$ht_params,$tmpl_params,$tmpl_name) = @_;
         $self->query->param('load_tmpl_hook' => 1);
         $tmpl_params->{'ping'} = 'ping_hook';
         $self->param('found_file_name',$tmpl_name);    

     });
     my $t = $app->load_tmpl('t/lib/templates/test.tmpl',  );
     my $out = $app->run;
     like($out, qr/load_tmpl_hook/, "adding load_tmpl callback causes load_tmpl_hook to appear");
     like($t->output, qr/ping_hook/, 'load_tmpl callback affected template' ); 

    is( $app->param('found_file_name'), 't/lib/templates/test.tmpl', 
        'template name passed into callback works');

}



