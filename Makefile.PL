# $Id: Makefile.PL,v 1.4 2000/07/06 17:20:13 jesse Exp $
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	'NAME'	=> 'CGI::Application',
	'VERSION_FROM' => 'Application.pm', # finds $VERSION
	'PREREQ_PM' => {
		'CGI' => 0, 
		'HTML::Template' => 0,
	},   # Packages used by CGI::Application
);
