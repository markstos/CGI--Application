# $Id: Application.pm,v 1.3 2000/07/06 12:22:03 jesse Exp $

package CGI::Application;

use strict;
use vars qw($VERSION);

$VERSION = '1.0';


use CGI;
use CGI::Carp;
use HTML::Template;



###################################
####  INSTANCE SCRIPT METHODS  ####
###################################

sub new {
	my $class = shift;
	my @args = @_;

	if (ref($class)) {
		# No copy constructor yet!
		$class = ref($class);
	}

	# Create our object!
	my $self = {};
	bless($self, $class);

	### SET UP DEFAULT VALUES ###
	#
	# We set them up here and not in the setup() because a subclass 
	# which implements setup() still needs default values!

	$self->header_type('header');
	$self->mode_param('rm');
	$self->start_mode('start');

	# Process optional new() parameters
	my $rprops;
	if (ref($args[0]) eq 'HASH') {
		my $rthash = %{$args[0]};
		$rprops = $self->_cap_hash($args[0]);
	} else {
		$rprops = $self->_cap_hash({ @args });
	}

	# Set tmpl_path()
	if (exists($rprops->{TMPL_PATH})) {
		$self->tmpl_path($rprops->{TMPL_PATH});
	} else {
		$self->tmpl_path('./');
	}

	# Set up init param() values
	if (exists($rprops->{PARAMS})) {
		croak("PARAMS is not a hash ref") unless (ref($rprops->{PARAMS}) eq 'HASH');
		my $rparams = $rprops->{PARAMS};
		while (my ($k, $v) = each(%$rparams)) {
			$self->param($k, $v);
		}
	}

	# Call setup() method, which should be implemented in the sub-class!
	$self->setup();

	return $self;
}


sub run {
	my $self = shift;
	my $q = $self->query();

	my $rm_param = $self->mode_param() || croak("No rm_param() specified");
	my $def_rm = $self->start_mode() || '';
	my $rm = $q->param($rm_param) || $def_rm;

	my $rmeth = $self->run_modes()->{$rm}
		|| croak("No function specified for run mode '$rm'");

	my $output = $rmeth->($self);

	$self->_send_headers();
	print $output;

	# clean up operations
	$self->teardown();
}




############################
####  OVERRIDE METHODS  ####
############################

sub setup {
	my $self = shift;
}


sub teardown {}




######################################
####  APPLICATION MODULE METHODS  ####
######################################

sub dump {}


sub dump_html {}


sub header_props {}


sub header_type {}


sub load_tmpl {}


sub mode_param {}


sub param {
	my $self = shift;
	my ($param, $value) = @_;

	# First use?  Create new __PARAMS!
	$self->{__PARAMS} = {} unless (exists($self->{__PARAMS}));

	# Return the list of param keys if no param is specified.
	return (keys(%{$self->{__PARAMS}})) unless(defined($param));

	# If a value is specified, set it!
	if (defined($value)) {
		$self->{__PARAMS}->{$param} = $value;
	}

	# If we've goten this far, return the param value!
	return $self->{__PARAMS}->{$param};
}


sub query {}


sub run_modes {}


sub start_mode {}


sub tmpl_path {}




###########################
####  PRIVATE METHODS  ####
###########################


sub _send_headers {
	my $self = shift;
	my $q = $self->query();

	if ($self->header_type() =~ /redirect/i) {
		print $q->redirect(%{$self->header_props()});
	} else {
		print $q->header(%{$self->header_props()});
	}
}


# Make all hash keys CAPITAL
sub _cap_hash {
	my $self = shift;
	my $rhash = shift;
	my %hash = map {
		my $k = $_;
		my $v = $rhash->{$k};
		$k =~ tr/a-z/A-Z/;
		$k => $v;
	} keys(%{$rhash});
	return \%hash;
}



1;




=pod

=head1 NAME

CGI::Application - 
Framework for building reusable web-applications


=head1 SYNOPSIS

  # WebApp.pm
  package WebApp;
  use base 'CGI::Application';
  sub setup {
	my $self = shift;
	$self->start_mode('mode1');
	$self->mode_param('rm');
	$self->run_modes(
		'mode1' => \&do_stuff,
		'mode2' => \&do_more_stuff
	);
  }
  sub teardown {
	my $self = shift;
	# Post-response shutdown functions
  }
  sub do_stuff { ... }
  sub do_more_stuff { ... }
 
 
  # webapp.cgi
  use WebApp;
  my $webapp = WebApp->new();
  $webapp->run();


=head1 USAGE EXAMPLE

CGI::Application is intended to make it easier to create sophisticated, 
reusable web-based applications.  This module implements a methodology 
which, if followed, will make your web software easier to design, 
easier to document, easier to write, and easier to evolve.

Following is an example of the typical usage of CGI::Application.

Imagine you have to write an application to search through a database
of widgets.  Your application has three screens:

   1. Search form
   2. List of results
   3. Detail of a single record

To write this application using CGI::Application you will create two files:

   1. WidgetView.pm -- Your "Application Module"
   2. widgetview.cgi -- Your "Instance Script"

The Application Module contains all the code specific to your 
application functionality, and it exists outside of your web server's
document root, somewhere in the Perl library search path.

The Instance Script is what is actually called by your web server.  It is 
a very small, simple file which simply creates an instance of your 
application and calls an inherited method, run().  Following is the 
entirety of "widgetview.cgi":

   #!/usr/bin/perl -w
   use WidgetView;
   my $webapp = WidgetView->new();
   $webapp->run();

As you can see, widgetview.cgi simply "uses" your Application module 
(which implements a Perl package called "WidgetView").  Your Application Module, 
"WidgetView.pm", is somewhat more lengthy:

   package WidgetView;
   use base 'CGI::Application';
   use strict;

   # Needed for our database connection
   use DBI;

   sub setup {
	my $self = shift;
	$self->start_mode('mode1');
	$self->run_modes(
		'mode1' => \&showform,
		'mode2' => \&showlist,
		'mode3' => \&showdetail
	);

	# Connect to DBI database
	$self->param('mydbh' => DBI->connect());
   }

   sub teardown {
	my $self = shift;

	# Disconnect when we're done
	$self->param('mydbh')->disconnect();
   }

   sub showform {
	my $self = shift;

	# Get CGI query object
	my $q = $self->query();

	my $output = '';
	$output .= $q->start_html(-title => 'Widget Search Form');
	$output .= $q->start_form();
	$output .= $q->textfield(-name => 'widgetcode');
	$output .= $q->hidden(-name => 'rm', -value => 'mode2');
	$output .= $q->submit();
	$output .= $q->end_form();
	$output .= $q->end_html();

	return $output;
   }

   sub showlist {
	my $self = shift;

	# Get our database connection
	my $dbh = $self->param('mydbh');

	# Get CGI query object
	my $q = $self->query();
	my $widgetcode = $q->param("widgetcode");

	my $output = '';
	$output .= $q->start_html(-title => 'List of Matching Widgets');

	## Do a bunch of stuff to select "widgets" from a DBI-connected
	## database which match the user-supplied value of "widgetcode"
	## which has been supplied from the previous HTML form via a 
	## CGI.pm query object.
	##
	## Each row will contain a link to a "Widget Detail" which 
	## provides an anchor tag, as follows:
	##
	##   "widgetview.cgi?rm=mode3&widgetid=XXX"
	##
	##  ...Where "XXX" is a unique value referencing the ID of
	## the particular "widget" upon which the user has clicked.

	$output .= $q->end_html();

	return $output;
   }

   sub showdetail {
	my $self = shift;

	# Get our database connection
	my $dbh = $self->param('mydbh');

	# Get CGI query object
	my $q = $self->query();
	my $widgetid = $q->param("widgetid");

	my $output = '';
	$output .= $q->start_html(-title => 'Widget Detail');

	## Do a bunch of things to select all the properties of  
	## the particular "widget" upon which the user has
	## clicked.  The key id value of this widget is provided 
	## via the "widgetid" property, accessed via the CGI.pm
	## query object.

	$output .= $q->end_html();

	return $output;
   }


CGI::Application takes care of implementing the new() and the run() 
methods.  Notice that at no point do you call print() to send any 
output to STDOUT.  Instead, all output is returned as a scalar.

CGI::Application's most significant contribution is in managing 
the application state.  Notice that all which is needed to push
the application forward is to set the value of a HTML form 
parameter 'rm' to the value of the "run mode" you wish to handle
the form submission.  This is the key to CGI::Application.


=head1 ABSTRACT

The guiding philosophy behind CGI::Application is that a web-based 
application can be organized into a specific set of "Run-Modes."
Each Run-Mode is roughly analogous to a single screen (a form, some 
output, etc.).  All the Run-Modes are managed by a single "Application 
Module" which is a Perl module.  In your web server's document space
there is an "Instance Script" which is called by the web server as a 
CGI (or an Apache::Registry script if you're using Apache + mod_perl).

This methodology is an inversion of the "Embedded" philosophy (ASP, JSP, 
EmbPerl, Mason, etc.) in which there are "pages" for each state of the 
application, and the page drives functionality.  In CGI::Application, 
form follows function -- the Application Module drives pages, and the 
code for a single application is in one place; not spread out over 
multiple "pages".  If you feel that Embedded architectures are 
confusing, unorganized, difficult to design and difficult to manage, 
CGI::Application is the methodology for you!

Apache is NOT a requirement for CGI::Application.  Web applications based on 
CGI::Application will run equally well on NT/IIS or any other 
CGI-compatible environment.  CGI::Application-based applications 
are, however, ripe for use on Apache/mod_perl servers, as they 
naturally encourage Good Programming Practices.  As always, use strict!


=head1 DESCRIPTION

CGI::Application is an Object-Oriented Perl module which implements an 
Abstract Class.  It is not intended that this package be instantiated 
directly.  Instead, it is intended that your Application Module will be 
implemented as a Sub-Class of CGI::Application.

To inherit from CGI::Application, the following code should go at 
the beginning of your Application Module, after your package declaration:

    use base 'CGI::Application';


B<Notation and Conventions>

For the purpose of this document, we will refer to the 
following conventions:

  WebApp.pm   The Perl module which implements your Application Module class.
  WebApp      Your Application Module class; a sub-class of CGI::Application.
  webapp.cgi  The Instance Script which implements your Application Module.
  $webapp     An instance (object) of your Application Module class.
  $self       Same as $webapp, used in instance methods to pass around the 
              current object. (Standard Perl Object-Oriented technique)




=head2 Instance Script Methods

By inheriting from CGI::Application you have access to a
number of built-in methods.  The following are those which
are expected to be called from your Instance Script.


=over 4

=item new()

The new() method is the constructor for an OOCGI.  It returns a blessed 
reference to your Application Module package (class).  Optionally, new() 
may take a set of parameters as key => value pairs:

    my $webapp = App->new(
		TMPL_PATH => 'App/',
		PARAMS => {
			'custom_thing_1' => 'some val',
			'another_custom_thing' => [qw/123 456/]
		}
    );

This method may take some specific parameters:

TMPL_PATH     - This optional parameter adds value to the load_tmpl() 
method (specified below).  This sets a path which is prepended to 
all the filenames specified when you call load_tmpl() to get your 
HTML::Template object.  This run-time parameter allows you to 
further encapsulate instantiating templates, providing potential 
for more reusability.

PARAMS        - This parameter, if used, allows you to set a number 
of custom parameters at run-time.  By passing in different 
values in different instance scripts which use the same application 
module you can achieve a higher level of reusability.  For instance, 
imagine an application module, "MailForm.pm".  The application takes 
the contents of a HTML form and emails it to a specified recipient.
You could have multiple instance scripts throughout your site which 
all use this "MailForm.pm" module, but which set different recipients
or different forms.


=item run()

The run() method is called upon your Application Module object, from
your Instance Script.  When called, it executes the functionality 
in your Application Module.

    my $webapp = WebApp->new();
    $webapp->run();

This method first determines the application state by looking at the 
value of the CGI parameter specified by mode_param() (defaults to 
'rm' for "Run Mode"), which is expected to contain the name of the mode of 
operation.  If not specified, the state defaults to the value 
of start_mode().

Once the mode has been determined, run() looks at the dispatch 
table stored in run_modes() and finds the function pointer which 
is keyed from the mode name.  If found, the function is called and the 
data returned is print()'ed to STDOUT and to the browser.  If 
the specified mode is not found in the run_modes() table, run() will 
croak().
 

=back


=head2 Sub-classing and Override Methods

CGI::Application implements some methods which are expected to be overridden 
by implementing them in your sub-class module.  These methods are as follows:

=over 4

=item setup()

This method is called by the inherited new() constructor method.  The 
setup() method should be used to define the following property/methods:

    mode_param() - set the name of the run mode CGI param.
    start_mode() - text scalar containing the default run mode.
    run_modes() - hash table containing mode => function mappings.
    tmpl_path() - text scalar containing path to template files.

Your setup() method may call any of the instance methods of your application.
This function is a good place to define properties specific to your application
via the $webapp->param() method.

Your setup() method might be implemented something like this:

	sub setup {
		my $self = shift;
		$self->tmpl_path('/path/to/my/templates/');
		$self->start_mode('putform');
		$self->run_modes({
			'putform' => \&my_putform_func,
			'postdata' => \&my_data_func
		});
		$self->param('myprop1');
		$self->param('myprop2', 'prop2value');
		$self->param('myprop3', ['p3v1', 'p3v2', 'p3v3']);
	}

=item teardown()

This method is called automatically after your application runs.  It 
can be used to clean up after your operations.  A typical use of the 
teardown() function is to disconnect a database connection which was
established in the setup() function.  You could also use the teardown()
method to store state information about the application to the server.
 

=back


=head2 Application Module Methods

The following methods are inherited from CGI::Application, and are 
available to be called by your application within your Application
Module.  These functions are listed in alphabetical order.


=over 4

=item dump()

    print STDERR $webapp->dump();

The dump() method is a debugging function which will return a 
chunk of text which contains all the environment and CGI form 
data of the request, formatted nicely for human readability.  
Useful for outputting to STDERR.


=item dump_html()

    my $output = $webapp->dump_html();

The dump_html() method is a debugging function which will return 
a chunk of text which contains all the environment and CGI form 
data of the request, formatted nicely for human readability via 
a web browser.  Useful for outputting to a browser.


=item header_props()

    $webapp->header_props(-type=>'image/gif',-expires=>'+3d');

The header_props() method expects a hash of CGI.pm-compatible 
HTTP header properties.  These properties will be passed directly 
to CGI.pm's header() or redirect() methods.  Refer to L<CGI> 
for usage details.


B<IMPORTANT NOTE REGARDING HTTP HEADERS>

It is through the header_props() method that you may modify the outgoing 
HTTP headers.  This is necessary when you want to set a cookie, set the mime 
type to something other than "text/html", or perform a redirect.  The 
header_props() method works in conjunction with the header_type() method.  
The value contained in header_type() determines if we use CGI::header() or 
CGI::redirect().  The content of header_props() is passed as an argument to 
whichever CGI.pm function is called.

Understanding this relationship is important if you wish to manipulate 
the HTTP header properly.


=item header_type([<'header' || 'redirect'>])

    $webapp->header_type('redirect');

The header_type() method expects to be passed either 'header' or 'redirect'.
This method specifies the type of HTTP headers which should be sent back to 
the browser.  If not specified, defaults is 'header'.  See the 
header section of L<CGI> for details.


=item load_tmpl()

    my $tmpl_obj = $webapp->load_tmpl('some.tmpl');

This method takes the name of a template file and returns an 
HTML::Template object.  Refer to L<HTML::Template> for specific usage.

If tmpl_path() has been specified, load_tmpl() will prepend the tmpl_path()
property to the filename provided.  This further assists in encapsulating 
template usage.


=item mode_param()

    $webapp->mode_param('rm');

This accessor/mutator method is generally called in the setup() method.  
The mode_param() method sets the name of the CGI form parameter which contains the 
run mode of the application.  If not specified, the default value is 'rm'.  
This CGI parameter is queried by the run() method to send the program to the correct mode.


=item param()

    $webapp->param('pname', $somevalue);

The param() method provides a facility through which you may set 
application instance properties which are accessible throughout 
your application.

The param() method may be used in two basic ways.  First, you may use it 
to get or set the value of a parameter:

    $webapp->param('scalar_param', '123');
    my $scalar_param_values = $webapp->param('some_param');

Second, when called in the context of an array, with no parameter name
specified, param() returns an array containing all the parameters which
currently exist:

    my @all_params = $webapp->param();

The param() method enables a very valuable system for 
customizing your applications on a per-instance basis.  
One Application Module might be instantiated by different 
Instance Scripts.  Each Instance Script might set different values for a 
set of parameters.  This allows similar applications to share a common 
code-base, but behave differently.  For example, imagine a mail form 
application with a single Application Module, but multiple Instance 
Scripts.  Each Instance Script might specify a different recipient.
Another example would be a web bulletin boards system.  There could be 
multiple boards, each with a different topic and set of administrators.

The new() method provides a shortcut for specifying a number of run-time
parameters at once.  Internally, CGI::Application calls the param() 
method to set these properties.  The param() method is a powerful tool for 
greatly increasing your application's reusability.


=item query()

    my $q = $webapp->query();
    my $remote_user = $q->remote_user();

This method retrieves the CGI.pm query object which has been created 
by instantiating your Application Module.  For details on usage of this 
query object, refer to L<CGI>.  CGI::Application is built on the CGI 
module.  Generally speaking, you will want to become very familiar 
with CGI.pm, as you will use the query object whenever you want to 
interact with form data.

When the new() method is called, a CGI query object is automatically created.
If, for some reason, you want to use your own CGI query object, the new()
method supports passing in your existing query object on construction.


=item run_modes()

    $webapp->run_modes('mode1' => \&some_sub, 'mode2' => \&some_other_sub);

This accessor/mutator expects a hash which specifies the dispatch table for the 
different CGI states.  The run method uses the data in this table 
to send the CGI to the correct function as determined by reading 
the CGI parameter specified by mode_param() (defaults to 'rm' for "Run 
Mode").

The hash table set by this method is expected to contain the mode 
name as a key.  The value should be a pointer to the function which 
you want to be called when the CGI enters the specified mode:

    'mode_name' => \&mode_function

The function referenced is expected to return a chunk of text which 
will eventually be sent back to the web browser.

B<IMPORTANT NOTE ABOUT RUN MODE FUNCTIONS>

Your application should *NEVER* print() to STDOUT.
Using print() to send output to STDOUT (including HTTP headers) is 
exclusively the domain of the inherited run() method.  Breaking this 
rule is a common source of errors.  If your program is erroneously 
sending content before your HTTP header, you are probably breaking this rule.



=item start_mode()

    $webapp->start_mode('mode1');

The start_mode contains the name of the mode as specified in the run_modes() 
table.  Default mode is "start".  The mode key specified here will be used 
whenever the value of the CGI form parameter specified by mode_param() is 
not defined.  Generally, this is the first time your application is executed.


=item tmpl_path()

    $webapp->tmpl_path('/path/to/some/templates');

This access/mutator method sets the file path to the directory where the templates 
are stored.  It is used by load_tmpl() to find the template files.  The default 
value is "./" for the current directory.


=back



=head1 SEE ALSO

L<CGI>, L<HTML::Template>, perl(1)

=head1 AUTHOR

Jesse Erlbaum <jesse@vm.com>

B<Support Mailing List>

If you have any questions, comments, bug reports or feature suggestions, 
post them to the support mailing list!  To join the mailing list, simply
send a blank message to "cgiapp-subscribe@lists.vm.com".

=head1 LICENSE

Copyright (c) 2000, Jesse Erlbaum <jesse@vm.com> and 
Vanguard Media (http://www.vm.com).  All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

