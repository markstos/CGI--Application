use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'CGI::Application',
    'VERSION_FROM' => 'Application.pm', # finds $VERSION
);
