# $Id: Build.PL,v 1.2 2004/02/14 02:09:17 mark Exp $
use Module::Build;
my $build = Module::Build->new
  (
   module_name => 'CGI::Application',
   license => 'perl',
   requires => {
       # For Moved vs Found change
       'CGI'            => 0, 
       'HTML::Template' => 0,
       'Test::More'     => 0.47,
	   'Carp'		    => 0,
       'Class::ISA'     => 0,
       },
   'dist_author'        => [
            'Jesse Erlbaum <jesse@erlbaum.net>',
            'Mark Stosberg <mark@summersault.com>',
            'with the help of many others!' 
            ],
   'dist_abstract'      => 'Framework for building reusable web-applications',
   create_makefile_pl   => 'traditional',
   meta_add             => {
        no_index =>  { file => [ <test/*.pm> ] }, 
   },
  );

$build->create_build_script;

