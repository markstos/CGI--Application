# $Id: Build.PL,v 1.2 2004/02/14 02:09:17 mark Exp $
use Module::Build;
my $build = Module::Build->new
  (
   module_name => 'CGI::Application',
   license => 'perl',
   requires => {
       'CGI'            => 0, 
       'HTML::Template' => 0,
       'Test::More'     => 0,
	'Carp'		=> 0,
       },
   'dist_author'        => 'Jesse Erlbaum <jesse@erlbaum.net>',
   'dist_abstract'      => 'Framework for building reusable web-applications',
   create_makefile_pl   => 'traditional',
  );

$build->create_build_script;

