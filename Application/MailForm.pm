# $Id: MailForm.pm,v 1.2 2001/08/19 16:38:08 jesse Exp $

package CGI::Application::MailForm;

# Always use strict!
use strict;


# This is a CGI::Application module
use base 'CGI::Application';



# Required, but not enforced by Makefile.PL!
use Net::SMTP;




#############################################
##  OVERRIDE METHODS
##

sub setup {
	my $self = shift;

	$self->start_mode('sendmail');
	$self->run_modes(
		'sendmail' => 'sendmail',
	);
}



#############################################
##  RUN-MODE METHODS
##

sub sendmail {
	my $self = shift;

	return $self->dump_html();
}



#############################################
##  PRIVATE METHODS
##





#############################################
##  POD
##

=pod

=head1 NAME

CGI::Application::MailForm -
A simple HTML form to email system


=head1 SYNOPSIS

  # In "mailform.cgi" --
  use CGI::Application::MailForm;

  # Create a new MailForm instance...
  my $mf = CGI::Application::MailForm->new();

  # Configure your mailform
  $mf->param('SMTP_HOST'   => 'mail.your.domain');
  $mf->param('MAIL_FROM'   => 'webmaster@your.domain');
  $mf->param('MAIL_TO'     => 'form_recipient@your.domain');
  $mf->param('SUBJECT'     => 'New form submission!');
  $mf->param('SUCCESS_REDIRECT_URL' => '/uri/or/url/to/thankyou.html');
  $mf->param('FORM_FIELDS' => [qw/name address comments etc/]);
  $mf->param('ENV_FIELDS'  => [qw/REMOTE_ADDR HTTP_USER_AGENT/]);

  # Now run...
  $mf->run();
  exit(0);


 
  # In "mailform.html" --
  <form action="mailform.cgi">
  <!-- Your HTML form input fields here -->
  <input type="submit" name="submit">
  </form>


=head1 DESCRIPTION

CGI::Application::MailForm is a simple, reusable and customizable mail-form
for the web.  It is intentionally simple, and provides very few facilities.
What it does do is provide a simple and secure system for taking the contents 
of a HTML form submission and sending it, via email, to a specified recipient.

This module was created as an example of how to use CGI::Application, a 
framework for creating reusable web-based applications.  In addition to 
providing a simple example of CGI::Application's usage, 
CGI::Application::MailForm is also a fully functional application, 
capable of running in a production environment.

Just as is the case with any web-application built upon CGI::Application, 
CGI::Application::MailForm will run on any web server and operating system
which supports the Common Gateway Interface (CGI).  It will run equally
well on Apache as it runs on IIS or the iPlanet server.  It will run
perfectly well on UNIX, Linux, Solaris or Windows NT.  It will take full
advantage of the advanced capabilities of MOD_PERL.  It will probably
even run under FastCGI (although the author has not personally tested it
in that environment).



=head2 USAGE

Once CGI::Application::MailForm has been installed, you must complete the 
following steps to create a custom mailform on your website:

  1. Create 'mailform.html'
  2. Create 'mailform.cgi'
  3. Create 'thankyou.html'

Examples of these files are provided in the directory "Examples" 
which can be found in the installation tar file for CGI::Application.


=head2 Create 'mailform.html'

The file 'mailform.html' is simply an HTML file which contains your web form.  
This is the form whose contents will be sent, via CGI::Application::MailForm,
to the specified recipient's email address.

This file need only contain the basic HTML form.  The only requirement
is that the "action" attribute of the <form> element must refer to the 
CGI "instance script" which you are about to create in the next step ('mailform.cgi').

For example:

    <form action="mailform.cgi">
    <!-- Your HTML form input fields go here -->
    </form>

Your 'mailform.html' may also contain JavaScript to provide form validation.
The CGI::Application::MailForm does not (currently) have any internal form 
validation capabilities.  As described earlier, this is a very simple system.
If it is necessary to enforce any fields as "required", it is recommended that
JavaScript be used.

NOTE:  It is not necessary that your HTML file be called 'mailform.html'.  
You may name this file anything you like.



=head2 Create 'mailform.cgi'

The file 'mailform.cgi' is where all the functionality of CGI::Application::MailForm
is configured.  This file is referred to as a "CGI instance script" because it 
creates an "instance" of your form.  A single website may have as many instance 
scripts as needed.  All of these instance scripts may use CGI::Application::MailForm.  
They may each use a different form (with different fields, etc.) if desired.  
The ability to create multiple instances of a single
application, each with a different configuration is one of the benefits
of building web-based applications using the CGI::Application framework.

Your instance script, 'mailform.cgi', must be created in such a way that it is 
treated by your web server as an executable CGI application (as opposed to a 
document).  Generally, this entails setting the "execute bit" on the file and 
configuring your web server to treat files ending ".cgi" as CGI applications.
Please refer to your particular web server's manual for configuration details.

Your instance script 'mailform.cgi' must start with the following:

    #!/usr/bin/perl -w
    use CGI::Application::MailForm;
    my $mf = CGI::Application::MailForm->new();

These lines invoke the Perl interpreter, include the CGI::Application::MailForm
module, and instantiate a MailForm object, respectively.  (The
author assumes your perl binary is located at "/usr/bin/perl".  If it is not, 
change the first line to refer to the correct location of your Perl binary.)

Once you have a MailForm object ($mf), you have to configure the MailForm for your 
particular application.  This is done by using the param() method to set a number of 
variables.  These variables are specified as follows.

=over 4

=item SMTP_HOST

This variable specifies the Internet host name  (or IP address) of the
server which provides Simple Mail Transfer Protocol (SMTP) services.
CGI::Application::MailForm sends all mail via SMTP using Net::SMTP.

If SMTP_HOST is unspecified, Net::SMTP will use the default host
which was specified when Net::SMTP was installed.  If 
CGI::Application::MailForm is unable to make an SMTP connection,
or successfully send mail via the SMTP host, it will die() with 
appropriate errors.


=item MAIL_FROM

This variable specifies the email address from which the email created by this 
mailform will appear to be sent.  This can be any address you like.
Typically, this will be "webmaster@your.domain".  Keep in mind, this is
the address to which a bounce or a reply will be sent if one is generated
as a result of the mailform email.  The MAIL_FROM can also be useful for 
assisting the recipient of these email messages in automatically filtering 
and organizing the submissions they receive.

This variable is required.


=item MAIL_TO

This variable specifies the email address to which the email created by this 
mailform should be sent.  This should be the email address of the person to
whom the form contents should be emailed.  This person will receive a 
reasonably formatted message every time this mailform is submitted.

This variable is required.


=item SUBJECT

This variable specifies the subject line of the email message which is 
created by this mailform.  The subject is useful to the mailform recipient
in easily recognizing (and possibly filtering) form submissions.

This variable is required.


=item SUCCESS_REDIRECT_URL

This variable specifies the URL (or URI) to which the web user should be
redirected once they have submitted the mailform.  Typically, this would be 
a "thank you" screen which assures the user that their form submission has 
been received and processed.

This variable is required.



=item FORM_FIELDS

This variable specifies the list of HTML form fields which will be 
processed and sent via email to the specified recipient.  Only the 
form fields specified in this list will be put in the email message
which is generated by this mailform and sent to the specified 
recipient.

The value of this variable must be an array reference.  This variable 
is required.


=item ENV_FIELDS


This variable specifies the list of "environment" variables which will be 
processed and sent via email to the specified recipient.  Only the 
environment variables specified in this list will be put in the email message
which is generated by this mailform and sent to the specified 
recipient.

Any environment variable which is present in the CGI
environment may be included.  Typical variables might be:

    SERVER_NAME 
    SERVER_PROTOCOL 
    SERVER_PORT 
    REQUEST_METHOD 
    PATH_INFO 
    PATH_TRANSLATED 
    SCRIPT_NAME 
    REMOTE_HOST 
    REMOTE_ADDR 
    CONTENT_LENGTH 
    HTTP_ACCEPT 
    HTTP_USER_AGENT

See your web server documentation for a complete list and descriptions 
of the available environment variables.  The list of environment variables 
specified by the CGI protocol can be found at the following URL:

    http://hoohoo.ncsa.uiuc.edu/cgi/env.html

The value of this variable must be an array reference.  This variable 
is optional.  If not specified, no environment variables will be included
in the mailform email message.

=back


Once you have configured your MailForm object, your instance script
might contain lines which look like this:

    $mf->param('SMTP_HOST'   => 'mail.host.address');
    $mf->param('MAIL_FROM'   => 'webmaster@host.address');
    $mf->param('MAIL_TO'     => 'form_recipient@host.address');
    $mf->param('SUBJECT'     => 'New form submission!');
    $mf->param('SUCCESS_REDIRECT_URL' => '/uri/or/url/to/thankyou.html');
    $mf->param('FORM_FIELDS' => [qw/name address comments etc/]);
    $mf->param('ENV_FIELDS'  => [qw/REMOTE_ADDR HTTP_USER_AGENT/]);


Finally, you must actually cause your MailForm to be executed by calling the run() 
method.  Your instance script 'mailform.cgi' should end with the following lines:

    $mf->run();
    exit(0);

These lines cause your configured MailForm ($mf) to be executed, and for the program to 
cleanly exit, respectively.

NOTE:  It is not necessary that your HTML file be called 'mailform.cgi'.  You may name 
this file anything you like.  The only naming limitations are that this file should be 
named so that your web server recognizes it as an executable CGI, and that your 
'mailform.html' file specifies your instance script in the "action" attribute of the 
<form> element.

All things considered, your CGI instance script will be a very small, simple file.  Unlike 
other reusable "mailform" scripts, the instance scripts are specifically intended to be
very easy to work with.  Essentially, these instance scripts are "configuration files" for
your web-based application.  The structure of instance scripts is a benefit of
building applications based on the CGI::Application framework.


=head2 Create 'thankyou.html'

The last file you need to create is your 'thankyou.html' file.  This file is the 
simplist of all.  This is the file to which users will be redirected once they have 
successfully submitted their form data.  The purpose of this screen is to inform
and assure the user that their form data submission has been successfully received
and processed.

For example:

    <html>
    <head>
        <title>Thank you!</title>
    </head>
    <body>
        <p><h1>Thanks for your submission!</h1></p>
        <p>We have received your form, and
        we will get back to you shortly.</p>
    </body>
    </html>

NOTE:  It is not necessary that your HTML file be called 'thankyou.html'.  You may name
this file anything you like.  The only naming limitation is that the name of this
file should be correctly referenced in your 'mailform.cgi', in the variable 'SUCCESS_REDIRECT_URL'.



=head1 SEE ALSO

L<CGI::Application>


=head1 AUTHOR

Jesse Erlbaum <jesse@vm.com>


=head1 LICENSE

Copyright (c) 2000, Jesse Erlbaum <jesse@vm.com> and
Vanguard Media (http://www.vm.com).  All rights reserved.

This library is free software; you can redistribute it
and/or modify it under the same terms as Perl itself.




=cut




1;

