# $Id: Makefile.PL,v 1.2 2000/07/05 11:05:05 jesse Exp $
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'	=> 'CGI::Application',
    'VERSION_FROM' => 'Application.pm', # finds $VERSION
);
