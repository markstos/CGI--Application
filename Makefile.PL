# $Id: Makefile.PL,v 1.7 2002/07/18 11:50:20 jesse Exp $
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
	'NAME'	=> 'CGI::Application',
	'VERSION_FROM' => 'Application.pm', # finds $VERSION
	'PREREQ_PM' => {
		'CGI' => 0, 
		'HTML::Template' => 0,
		'Test::More' => 0,
	},   # Packages used by CGI::Application
	($] ge '5.005') ? (
		'AUTHOR' => 'Jesse Erlbaum (jesse@erlbaum.net)',
		'ABSTRACT' => 'Framework for building reusable web-applications',
	) : (),   # For ActivePerl PPM
);
