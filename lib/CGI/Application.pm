# $Id: Application.pm,v 1.13 2001/05/28 18:22:00 jesse Exp $

package CGI::Application;

use strict;

$CGI::Application::VERSION = '1.31';


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
	}

	# Set CGI query object
	if (exists($rprops->{QUERY})) {
		$self->query($rprops->{QUERY});
	}

	# Set up init param() values
	if (exists($rprops->{PARAMS})) {
		croak("PARAMS is not a hash ref") unless (ref($rprops->{PARAMS}) eq 'HASH');
		my $rparams = $rprops->{PARAMS};
		while (my ($k, $v) = each(%$rparams)) {
			$self->param($k, $v);
		}
	}

	# Call cgiapp_init() method, which may be implemented in the sub-class.
	# Pass all constructor args forward.  This will allow flexible usage 
	# down the line.
	$self->cgiapp_init(@args);

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

	my %rmodes = ($self->run_modes());
	my $rmeth = $rmodes{$rm}
		|| croak("No function specified for run mode '$rm'");

	# Process run mode!
	my $body;
	if (ref($rmeth) eq 'CODE') {
		$body = $rmeth->($self);
	} else {
		my $meth_call = '$self->' . $rmeth;
		$body = eval($meth_call);
		die ("Error executing run mode '$rm'.  Eval of code '$meth_call' resulted in error: " . $@) if ($@);
	}

	# Set up HTTP headers
	my $headers = $self->_send_headers();

	# Build up total output
	my $output = $headers . $body;

	# Send output to browser (unless we're in serious debug mode!)
	unless ($ENV{CGI_APP_RETURN_ONLY}) {
		print $output;
	}

	# clean up operations
	$self->teardown();

	return $output;
}




############################
####  OVERRIDE METHODS  ####
############################

sub cgiapp_init {
	my $self = shift;

	# Nothing to init, yet!
}


sub setup {
	my $self = shift;

	$self->start_mode('start');
	$self->run_modes(
		'start' => \&dump_html,
	);
}


sub teardown {
	my $self = shift;

	# Nothing to shut down, yet!
}




######################################
####  APPLICATION MODULE METHODS  ####
######################################

sub dump {
	my $self = shift;
	my $output = '';

	# Dump Params
	$output .= "Query Parameters:\n";
	my @params = $self->query->param();
	foreach my $p (sort(@params)) {
		my @data = $self->query->param($p);
		my $data_str = "'".join("', '", @data)."'";
		$output .= "\t$p => $data_str\n";
	}

	# Dump ENV
	$output .= "\nQuery Environment:\n";
	foreach my $ek (sort(keys(%ENV))) {
		$output .= "\t$ek => '".$ENV{$ek}."'\n";
	}

	return $output;
}


sub dump_html {
	my $self = shift;
	my $output = '';

	# Dump Params
	$output .= "<P>\nQuery Parameters:<BR>\n<OL>\n";
	my @params = $self->query->param();
	foreach my $p (sort(@params)) {
		my @data = $self->query->param($p);
		my $data_str = "'<B>".join("</B>', '<B>", @data)."</B>'";
		$output .= "<LI> $p => $data_str\n";
	}
	$output .= "</OL>\n";

	# Dump ENV
	$output .= "<P>\nQuery Environment:<BR>\n<OL>\n";
	foreach my $ek (sort(keys(%ENV))) {
		$output .= "<LI> $ek => '<B>".$ENV{$ek}."</B>'\n";
	}
	$output .= "</OL>\n";

	return $output;
}


sub header_props {
	my $self = shift;
	my (@data) = (@_);

	# First use?  Create new __HEADER_PROPS!
	$self->{__HEADER_PROPS} = {} unless (exists($self->{__HEADER_PROPS}));

	my $rh_p = $self->{__HEADER_PROPS};

	# If data is provided, set it!
	if (scalar(@data)) {
		# Is it a hash, or hash-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy
			%$rh_p = %{$data[0]};
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$rh_p = @data;
		} else {
			croak("Odd number of elements passed to header_props().  Not a valid hash")
		}
	}

	# If we've gotten this far, return the value!
	return (%$rh_p);
}


sub header_type {
	my $self = shift;
	my ($header_type) = @_;

	# First use?  Create new __HEADER_TYPE!
	$self->{__HEADER_TYPE} = 'header' unless (exists($self->{__HEADER_TYPE}));

	# If data is provided, set it!
	if (defined($header_type)) {
		$header_type = lc($header_type);
		croak("Invalid header type '$header_type'.  Header type must be 'header' or 'redirect'")
			unless(($header_type eq 'header') || ($header_type eq 'redirect'));
		$self->{__HEADER_TYPE} = $header_type;
	}

	# If we've gotten this far, return the value!
	return $self->{__HEADER_TYPE};
}


sub load_tmpl {
	my $self = shift;
	my ($tmpl_file, @extra_params) = @_;

	my $fq_tmpl_file = $self->tmpl_path() . $tmpl_file;

	my $t = HTML::Template->new_file($fq_tmpl_file, @extra_params);

	return $t;
}


sub mode_param {
	my $self = shift;
	my ($mode_param) = @_;

	# First use?  Create new __MODE_PARAM!
	$self->{__MODE_PARAM} = 'rm' unless (exists($self->{__MODE_PARAM}));

	# If data is provided, set it!
	if (defined($mode_param)) {
		$self->{__MODE_PARAM} = $mode_param;
	}

	# If we've gotten this far, return the value!
	return $self->{__MODE_PARAM};
}


sub param {
	my $self = shift;
	my ($param, $value) = @_;

	# First use?  Create new __PARAMS!
	$self->{__PARAMS} = {} unless (exists($self->{__PARAMS}));

	my $rp = $self->{__PARAMS};

	# Return the list of param keys if no param is specified.
	return (keys(%$rp)) unless(defined($param));

	# If a value is specified, set it!
	if (defined($value)) {
		$rp->{$param} = $value;
	}

	# If we've gotten this far, return the param value!
	return $rp->{$param};
}


sub query {
	my $self = shift;
	my ($query) = @_;

	# We're only allowed to set a new query object if one does not yet exist!
	unless (exists($self->{__QUERY_OBJ})) {
		my $new_query_obj;

		# If data is provided, set it!  Otherwise, create a new one.
		if (defined($query) && $query->isa('CGI')) {
			$new_query_obj = $query;
		} else {
			$new_query_obj = CGI->new();
		}

		$self->{__QUERY_OBJ} = $new_query_obj;
	}

	return $self->{__QUERY_OBJ};
}


sub run_modes {
	my $self = shift;
	my (@data) = (@_);

	# First use?  Create new __RUN_MODES!
	$self->{__RUN_MODES} = {} unless (exists($self->{__RUN_MODES}));

	my $rr_m = $self->{__RUN_MODES};

	# If data is provided, set it!
	if (scalar(@data)) {
		# Is it a hash, or hash-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy
			%$rr_m = %{$data[0]};
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$rr_m = @data;
		} else {
			croak("Odd number of elements passed to run_modes().  Not a valid hash")
		}
	}

	# If we've gotten this far, return the value!
	return (%$rr_m);
}


sub start_mode {
	my $self = shift;
	my ($start_mode) = @_;

	# First use?  Create new __START_MODE!
	$self->{__START_MODE} = 'start' unless (exists($self->{__START_MODE}));

	# If data is provided, set it!
	if (defined($start_mode)) {
		$self->{__START_MODE} = $start_mode;
	}

	# If we've gotten this far, return the value!
	return $self->{__START_MODE};
}


sub tmpl_path {
	my $self = shift;
	my ($tmpl_path) = @_;

	# First use?  Create new __TMPL_PATH!
	$self->{__TMPL_PATH} = '' unless (exists($self->{__TMPL_PATH}));

	# If data is provided, set it!
	if (defined($tmpl_path)) {
		$self->{__TMPL_PATH} = $tmpl_path;
	}

	# If we've gotten this far, return the value!
	return $self->{__TMPL_PATH};
}




###########################
####  PRIVATE METHODS  ####
###########################


sub _send_headers {
	my $self = shift;
	my $q = $self->query();

	if ($self->header_type() =~ /redirect/i) {
		return $q->redirect($self->header_props());
	} else {
		return $q->header($self->header_props());
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
		'mode1' => 'do_stuff',
		'mode2' => 'do_more_stuff',
		'mode3' => 'do_something_else'
	);
  }
  sub cgiapp_init {
	my $self = shift;
	# Optional Pre-setup initalization behaviors
  }
  sub teardown {
	my $self = shift;
	# Optional Post-response shutdown behaviors
  }
  sub do_stuff { ... }
  sub do_more_stuff { ... }
  sub do_something_else { ... }


  # webapp.cgi
  use WebApp;
  my $webapp = WebApp->new();
  $webapp->run();


=head1 USAGE EXAMPLE

CGI::Application is intended to make it easier to create sophisticated, 
reusable web-based applications.  This module implements a methodology 
which, if followed, will make your web software easier to design, 
easier to document, easier to write, and easier to evolve.

CGI::Application builds on standard, non-proprietary technologies
and techniques, such as the Common Gateway Interface and 
Lincoln D. Stein's excellent CGI.pm module.  CGI::Application 
judiciously avoids employing technologies and techniques which would
bind a developer to any one set of tools, operating system or 
web server.

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
		'mode1' => 'showform',
		'mode2' => 'showlist',
		'mode3' => 'showdetail'
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

The new() method is the constructor for a CGI::Application.  It returns 
a blessed reference to your Application Module package (class).  Optionally, 
new() may take a set of parameters as key => value pairs:

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
			'putform'  => 'my_putform_func',
			'postdata' => 'my_data_func'
		});
		$self->param('myprop1');
		$self->param('myprop2', 'prop2value');
		$self->param('myprop3', ['p3v1', 'p3v2', 'p3v3']);
	}

=item teardown()

If implemented, this method is called automatically after your application runs.  It 
can be used to clean up after your operations.  A typical use of the 
teardown() function is to disconnect a database connection which was
established in the setup() function.  You could also use the teardown()
method to store state information about the application to the server.


=item cgiapp_init()

If implemented, this method is called automatically right before the
setup() method is called.  This method provides an optional initalization
hook, which improves the object-oriented characteristics of 
CGI::Application.  The cgiapp_init() method receives, as its parameters,
all the arguments which were sent to the new() method.

An example of the benefits provided by utilizing this hook is 
creating a custom "application super-class" from which which all 
your CGI applicatons would inherit, instead of CGI::Application.

Consider the following:

  # In MySuperclass.pm:
  package MySuperclass;
  use base 'CGI::Application';
  sub cgiapp_init {
	my $self = shift;
	# Perform some project-specific init behavior
	# such as to load settings from a database or file.
  }


  # In MyApplication.pm:
  package MyApplication;
  use base 'MySuperclass';
  sub setup { ... }
  sub teardown { ... }
  # The rest of your CGI::Application-based follows...  


By using CGI::Application and the cgiapp_init() method as illustrated, 
a suite of applications could be designed to share certain 
characteristics.  This has the potential for much cleaner code 
built on object-oriented inheritance.


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
HTML::Template object.  The HTML::Template->new_file() constructor
is used for create the object.  Refer to L<HTML::Template> for specific usage
of HTML::Template.

If tmpl_path() has been specified, load_tmpl() will prepend the tmpl_path()
property to the filename provided.  This further assists in encapsulating 
template usage.

The load_tmpl() method will pass any extra paramaters sent to it directly to 
HTML::Template->new_file().  This will allow the HTML::Template object to be 
further customized:

    my $tmpl_obj = $webapp->load_tmpl('some_other.tmpl', 
         die_on_bad_params => 0,
         cache => 1
    );

If your application requires more specialized behavior than this, you are
encoraged to override load_tmpl() by implementing your own load_tmpl() 
in your CGI::Application sub-class application module.


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

    $webapp->run_modes('mode1' => 'some_sub_by_name', 'mode2' => \&some_other_sub_by_ref);

This accessor/mutator expects a hash which specifies the dispatch table for the 
different CGI states.  The run method uses the data in this table 
to send the CGI to the correct function as determined by reading 
the CGI parameter specified by mode_param() (defaults to 'rm' for "Run 
Mode").

The hash table set by this method is expected to contain the mode 
name as a key.  The value should be either a hard reference to the function which 
you want to be called when the CGI enters the specified mode, or the 
name of the function to be called:

    'mode_name_by_ref'  => \&mode_function
    'mode_name_by_name' => 'mode_function'

The function specified is expected to return a block of text which 
will eventually be sent back to the web browser.

An advantage of specifying your run mode functions by name instead of 
by reference is that you can more easily create derivative application 
using inheritance.  For instance, if you have a new application which is
exactly the same as an existing application with the exception of one
run mode, you could simply inherit from that other application and override
the run mode function which is different.  If you specified your run mode 
functions by reference, your child class would still use the function
from the parent class.

An advantage of specifying your run modes by reference instead of by name 
is performance.  Dereferencing a subref is faster than eval()-ing 
a code block.  If run-time performance is a significant issue, specify
your run mode functions by reference and not by name.


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

    $webapp->tmpl_path('/path/to/some/templates/');

This access/mutator method sets the file path to the directory where the templates 
are stored.  It is used by load_tmpl() to find the template files.

It is important to make sure your tmpl_path() ends with your operating system's
directory delimiter ('/' for UNIX, '\' for windows, ':' for Macintosh, etc).  The 
load_tmpl() method does not try to make sense of the various OS particularities -- 
it simply prepends tmpl_path() to the file name passed to load_tmpl().


=back



=head1 SEE ALSO

L<CGI>, L<HTML::Template>, perl(1)


=head1 AUTHOR

Jesse Erlbaum <jesse@vm.com>

B<Support Mailing List>

If you have any questions, comments, bug reports or feature suggestions, 
post them to the support mailing list!  To join the mailing list, simply
send a blank message to "cgiapp-subscribe@lists.vm.com".


=head1 CREDITS

Thanks go to my place of work, Vanguard Media (http://www.vm.com),
for funding the development of this library, and encouraging me to 
release it to the world.  If you need a web-application for your 
business, do check us out!

Many thanks to Sam Tregar (author of the most excellent 
HTML::Template module!) for his innumerable contributions 
to this module over the past year, and most of all for getting 
me off my ass to finally get this thing up on CPAN!


=head1 LICENSE

Copyright (c) 2000, Jesse Erlbaum <jesse@vm.com> and 
Vanguard Media (http://www.vm.com).  All rights reserved.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.


=cut

