use Module::Build;
my $build = Module::Build->new
  (
   module_name => 'CGI::Application',
   license => 'perl',
   requires => {
	    'Module::Build'  => 0,
	    'CGI'            => 0, 
	    'HTML::Template' => 0,
	    'Test::More'     => 0.47,
	    'Test::Requires' => 0, 
	    'Carp'	     => 0,
	    'Class::ISA'     => 0,
       },
    recommends => {
        CGI::PSGI       => 0.09, # If you want to use run_as_psgi()
    },
   'dist_author'        => [
            'Jesse Erlbaum <jesse@erlbaum.net>',
            'Mark Stosberg <mark@summersault.com>',
            'Martin McGrath <marto@cpan.org>',
            'with the help of many others!' 
            ],
   'dist_abstract'      => 'Framework for building reusable web-applications',
   create_makefile_pl   => 'traditional',
   meta_add             => {
        no_index =>  { file => [ <test/*.pm> ] }, 
   },
   meta_merge           => {
      resources => {
         repository => 'https://github.com/markstos/CGI--Application',
      },
   },
  );

$build->create_build_script;

