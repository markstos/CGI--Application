# $Id: Makefile.PL,v 1.5 2001/08/11 20:56:06 jesse Exp $
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
	($] ge '5.005') ? (
		'AUTHOR' => 'Jesse Erlbaum (jesse@vm.com)',
		'ABSTRACT' => 'Framework for building reusable web-applications',
	) : (),   # For ActivePerl PPM
);
