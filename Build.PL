use Module::Build;
my $build = Module::Build->new
  (
   module_name => 'PSGI::Application',
   license => 'perl',
   requires => {
       'CGI::PSGI'      => 0,
#       'HTML::Template' => 0,
       'Test::More'     => 0.47,
	   'Carp'		    => 0,
       'Any::Moose'     => 0,
       'Try::Tiny'      => 0,
       'parent'         => 0,
       },
    test_requires  => {
        Plack           => 0.9982, # for Plack::Test
    },
   'dist_author'        => [
            'Mark Stosberg <mark@summersault.com>',
            ],
   'dist_abstract'      => 'Lightweight web framework using PSGI and Mouse',
   create_makefile_pl   => 'traditional',
   meta_add             => {
        no_index =>  { file => [ <t/*.pm> ] },
   },
  );

$build->create_build_script;

