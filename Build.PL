# $Id: Build.PL,v 1.1 2004/01/31 23:33:10 mark Exp $
use Module::Build;
my $build = Module::Build->new
  (
   module_name => 'CGI::Application',
   license => 'perl',
   requires => {
       'CGI'            => 0, 
       'HTML::Template' => 0,
       'Test::More'     => 0,
       },
   'dist_author'        => 'Jesse Erlbaum <jesse@erlbaum.net>',
   'dist_abstract'      => 'Framework for building reusable web-applications',
   create_makefile_pl   => 'traditional',
  );

$build->create_build_script;

