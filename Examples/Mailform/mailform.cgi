#!/usr/bin/perl -w


####  INCLUDE MAILFORM MODULE  ###########################################
#
use CGI::Application::Mailform;


####  INSTANTIATE NEW MAILFORM OBJECT  ###################################
#
my $mf = CGI::Application::Mailform->new();


####  SET REQUIRED VARIABLES  ############################################
#
$mf->param( 'MAIL_TO'     => 'jesse-cgiappmf@erlbaum.net' );
$mf->param( 'MAIL_FROM'   => 
	$ENV{SERVER_ADMIN} || 
	($ENV{USER} || 'webmaster') . '@' . ($ENV{HOSTNAME} || $ENV{SERVER_NAME})   );
$mf->param( 'HTMLFORM_REDIRECT_URL' => 'mailform.html' );
$mf->param( 'SUCCESS_REDIRECT_URL' => 'thankyou.html' );
$mf->param( 'FORM_FIELDS' => [qw/
	company_name 
	email 
	mailform_is 
	name 
	perl_is 
	postal_address 
	sing_happy_bday   /] );


####  SET OPTIONAL VARIABLES  ############################################
#
$mf->param('SUBJECT'     => 'Another happy CGI::Application::Mailform user!');
$mf->param('ENV_FIELDS'  => [qw/
	AUTH_TYPE
	CONTENT_LENGTH
	CONTENT_TYPE
	GATEWAY_INTERFACE
	HTTP_ACCEPT
	HTTP_USER_AGENT
	PATH_INFO
	PATH_TRANSLATED
	QUERY_STRING
	REMOTE_ADDR
	REMOTE_HOST
	REMOTE_IDENT
	REMOTE_USER
	REQUEST_METHOD
	SCRIPT_NAME
	SERVER_NAME
	SERVER_PORT
	SERVER_PROTOCOL
	SERVER_SOFTWARE   /]);


####  RUN MAILFORM  ######################################################
#
$mf->run();


####  ALL DONE!  #########################################################
#
exit(0);
