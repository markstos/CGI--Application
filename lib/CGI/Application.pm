# $Id: Application.pm,v 1.42 2004/05/12 17:04:08 jesse Exp $

package CGI::Application;
use Carp;
use strict;

$CGI::Application::VERSION = '3.31';

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

	# Lock prerun_mode from being changed until cgiapp_prerun()
	$self->{__PRERUN_MODE_LOCKED} = 1;

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

	my $rm;

	# Support call-back instead of CGI mode param
	if (ref($rm_param) eq 'CODE') {
		# Get run mode from subref
		$rm = $rm_param->($self);
	}
	# support setting run mode from PATH_INFO
	elsif (ref($rm_param) eq 'HASH') {
		$rm = $rm_param->{run_mode};
	} 
	# Get run mode from CGI param
	else {
		$rm = $q->param($rm_param);
	}

	# If $rm undefined, use default (start) mode
	my $def_rm = $self->start_mode();
        $def_rm = '' unless defined $def_rm;
	$rm = $def_rm unless (defined($rm) && length($rm));

	# Set get_current_runmode() for access by user later
	$self->{__CURRENT_RUNMODE} = $rm;

	# Allow prerun_mode to be changed
	delete($self->{__PRERUN_MODE_LOCKED});

	# Call PRE-RUN hook, now that we know the run mode
	# This hook can be used to provide run mode specific behaviors
	# before the run mode actually runs.
	$self->cgiapp_prerun($rm);

	# Lock prerun_mode from being changed after cgiapp_prerun()
	$self->{__PRERUN_MODE_LOCKED} = 1;

	# If prerun_mode has been set, use it!
	my $prerun_mode = $self->prerun_mode();
	if (length($prerun_mode)) {
		$rm = $prerun_mode;
		$self->{__CURRENT_RUNMODE} = $rm;
	}

	my %rmodes = ($self->run_modes());

	my $rmeth;
	my $autoload_mode = 0;
	if (exists($rmodes{$rm})) {
		$rmeth = $rmodes{$rm};
	} else {
		# Look for run mode "AUTOLOAD" before dieing
		unless (exists($rmodes{'AUTOLOAD'})) {
			croak("No such run mode '$rm'");
		}
		$rmeth = $rmodes{'AUTOLOAD'};
		$autoload_mode = 1;
	}

	# Process run mode!
    my $body;
	eval {
        $body = $autoload_mode ? $self->$rmeth($rm) : $self->$rmeth();
	}; 
	if ($@) {
		my $error = $@;
		if (my $em = $self->error_mode) {
			$body = $self->$em( $error );
		} else {
            croak("Error executing run mode '$rm': $error");
		}
	}

    # Make sure that $body is not undefined (supress 'uninitialized value' warnings)
    $body = "" unless defined $body;

    # Support scalar-ref for body return
    my $bodyref = (ref($body) eq 'SCALAR') ? $body : \$body;

    # Call cgiapp_postrun() hook
    $self->cgiapp_postrun($bodyref);

	# Set up HTTP headers
	my $headers = $self->_send_headers();

	# Build up total output
	my $output  = $headers.$$bodyref;


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

sub cgiapp_get_query {
	my $self = shift;

	# Include CGI.pm and related modules
	require CGI;

	# Get the query object
	my $q = CGI->new();

	return $q;
}


sub cgiapp_init {
	my $self = shift;
	my @args = (@_);

	# Nothing to init, yet!
}


sub cgiapp_prerun {
	my $self = shift;
	my $rm = shift;

	# Nothing to prerun, yet!
}


sub cgiapp_postrun {
	my $self = shift;
	my $bodyref = shift;

	# Nothing to postrun, yet!
}


sub setup {
	my $self = shift;

	$self->start_mode('start');
	$self->run_modes(
		'start' => 'dump_html',
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

	# Dump run mode
	my $current_runmode = $self->get_current_runmode();
	$current_runmode = "" unless (defined($current_runmode));
	$output .= "Current Run mode: '$current_runmode'\n";

	# Dump Params
	$output .= "\nQuery Parameters:\n";
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
        my $self   = shift;
        my $query  = $self->query();
        my $output = '';

        # Dump run-mode                                                                                                                                                                  
        my $current_runmode = $self->get_current_runmode();
        $output .= "<p>Current Run-mode:
'<strong>$current_runmode</strong>'</p>\n";

        # Dump Params                                                                                                                                                                    
        $output .= "<p>Query Parameters:</p>\n";
        $output .= $query->Dump;

        # Dump ENV                                                                                                                                                                       
        $output .= "<p>Query Environment:</p>\n<ol>\n";
        foreach my $ek ( sort( keys( %ENV ) ) ) {
                $output .= sprintf(
                        "<li> %s => '<strong>%s</strong>'</li>\n",
                        $query->escapeHTML( $ek ),
                        $query->escapeHTML( $ENV{$ek} )
                );
        }                                                                                                                                                                                
        $output .= "</ol>\n";

        return $output;
}


sub header_add {
	my $self = shift;
    return $self->_header_props_update(\@_,add=>1);
}

sub header_props {
	my $self = shift;
    return $self->_header_props_update(\@_,add=>0);
}

# used by header_props and header_add to update the headers
sub _header_props_update {
    my $self     = shift;
    my $data_ref = shift;
    my %in       = @_;

    my @data = @$data_ref;

	# First use?  Create new __HEADER_PROPS!
	$self->{__HEADER_PROPS} = {} unless (exists($self->{__HEADER_PROPS}));

	my $props;

	# If data is provided, set it!
	if (scalar(@data)) {
		warn("header_props called while header_type set to 'none', headers will NOT be sent!") if $self->header_type eq 'none';
		# Is it a hash, or hash-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy
			%$props = %{$data[0]};
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$props = @data;
		} else {
            my $meth = $in{add} ? 'add' : 'props';
			croak("Odd number of elements passed to header_$meth().  Not a valid hash")
		}

        # merge in new headers, appending new values passed as array refs
        if ($in{add}) {
            for my $key_set_to_aref (grep { ref $props->{$_} eq 'ARRAY'} keys %$props) {
                my $existing_val = $self->{__HEADER_PROPS}->{$key_set_to_aref};
                next unless defined $existing_val;
                my @existing_val_array = (ref $existing_val eq 'ARRAY') ? @$existing_val : ($existing_val);
                $props->{$key_set_to_aref}  = [ @existing_val_array, @{ $props->{$key_set_to_aref} } ];
            }
            $self->{__HEADER_PROPS} = { %{ $self->{__HEADER_PROPS} }, %$props };
        }
        # Set new headers, clobbering existing values
        else {
            $self->{__HEADER_PROPS} = $props;
        }

	}

	# If we've gotten this far, return the value!
	return (%{ $self->{__HEADER_PROPS}});
}


sub header_type {
	my $self = shift;
	my ($header_type) = @_;

    my @allowed_header_types = qw(header redirect none);

	# First use?  Create new __HEADER_TYPE!
	$self->{__HEADER_TYPE} = 'header' unless (exists($self->{__HEADER_TYPE}));

	# If data is provided, set it!
	if (defined($header_type)) {
		$header_type = lc($header_type);
		croak("Invalid header_type '$header_type'")
			unless(grep { $_ eq $header_type } @allowed_header_types);
		$self->{__HEADER_TYPE} = $header_type;
	}

	# If we've gotten this far, return the value!
	return $self->{__HEADER_TYPE};
}


sub load_tmpl {
	my $self = shift;
	my ($tmpl_file, @extra_params) = @_;

	# add tmpl_path to path array if one is set, otherwise add a path arg
	if (my $tmpl_path = $self->tmpl_path) {
		my @tmpl_paths = (ref $tmpl_path eq 'ARRAY') ? @$tmpl_path : $tmpl_path;
		my $found = 0;
		for( my $x = 0; $x < @extra_params; $x += 2 ) {
			if ($extra_params[$x] eq 'path' and 
			ref $extra_params[$x+1] eq 'ARRAY') {
				unshift @{$extra_params[$x+1]}, @tmpl_paths;
				$found = 1;
				last;
			}
		}
		push(@extra_params, path => [ @tmpl_paths ]) unless $found;
	}

	require HTML::Template;
	my $t = HTML::Template->new_file($tmpl_file, @extra_params);

	return $t;
}




sub param {
	my $self = shift;
	my (@data) = (@_);

	# First use?  Create new __PARAMS!
	$self->{__PARAMS} = {} unless (exists($self->{__PARAMS}));

	my $rp = $self->{__PARAMS};

	# If data is provided, set it!
	if (scalar(@data)) {
		# Is it a hash, or hash-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy, which augments the existing contents (if any)
			%$rp = (%$rp, %{$data[0]});
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$rp = (%$rp, @data);
		} elsif (scalar(@data) > 1) {
			croak("Odd number of elements passed to param().  Not a valid hash");
		}
	} else {
		# Return the list of param keys if no param is specified.
		return (keys(%$rp));
	}

	# If exactly one parameter was sent to param(), return the value
	if (scalar(@data) <= 2) {
		my $param = $data[0];
		return $rp->{$param};
	}
	return;  # Otherwise, return undef
}


sub delete {
        my $self = shift;
        my ($param) = @_;
        #return undef it it isn't defined
        return undef if(!defined($param));
                                                                                                                                                             
        #simply delete this param from $self->{__PARAMS}
        delete $self->{__PARAMS}->{$param};
}
                                                                                                                                                             

sub query {
	my $self = shift;
	my ($query) = @_;

	# We're only allowed to set a new query object if one does not yet exist!
	unless (exists($self->{__QUERY_OBJ})) {
		my $new_query_obj;

		# If data is provided, set it!  Otherwise, create a new one.
		if (defined($query)) {
			$new_query_obj = $query;
		} else {
			$new_query_obj = $self->cgiapp_get_query();
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
		# Is it a hash, hash-ref, or array-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy, which augments the existing contents (if any)
			%$rr_m = (%$rr_m, %{$data[0]});
		} elsif (ref($data[0]) eq 'ARRAY') {
			# Convert array-ref into hash table
			foreach my $rm (@{$data[0]}) {
				$rr_m->{$rm} = $rm;
			}
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$rr_m = (%$rr_m, @data);
		} else {
			croak("Odd number of elements passed to run_modes().  Not a valid hash");
		}
	}

	# If we've gotten this far, return the value!
	return (%$rr_m);
}


sub start_mode {
	my $self = shift;
	my ($start_mode) = @_;

	# First use?  Create new __START_MODE
	$self->{__START_MODE} = 'start' unless (exists($self->{__START_MODE}));

	# If data is provided, set it
	if (defined($start_mode)) {
		$self->{__START_MODE} = $start_mode;
	}

	return $self->{__START_MODE};
}


sub error_mode {
	my $self = shift;
	my ($error_mode) = @_;

	# First use?  Create new __ERROR_MODE
	$self->{__ERROR_MODE} = undef unless (exists($self->{__ERROR_MODE}));

	# If data is provided, set it.
	if (defined($error_mode)) {
		$self->{__ERROR_MODE} = $error_mode;
	}

	return $self->{__ERROR_MODE};
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


sub prerun_mode {
	my $self = shift;
	my ($prerun_mode) = @_;

	# First use?  Create new __PRERUN_MODE
	$self->{__PRERUN_MODE} = '' unless (exists($self->{__PRERUN_MODE}));

	# Was data provided?
	if (defined($prerun_mode)) {
		# Are we allowed to set prerun_mode?
		if (exists($self->{__PRERUN_MODE_LOCKED})) {
			# Not allowed!  Throw an exception.
			croak("prerun_mode() can only be called within cgiapp_prerun()!  Error");
		} else {
			# If data is provided, set it!
			$self->{__PRERUN_MODE} = $prerun_mode;
		}
	}

	# If we've gotten this far, return the value!
	return $self->{__PRERUN_MODE};
}


sub get_current_runmode {
	my $self = shift;

	# It's OK if we return undef if this method is called too early
	return $self->{__CURRENT_RUNMODE};
}





###########################
####  PRIVATE METHODS  ####
###########################


sub _send_headers {
	my $self = shift;
	my $q = $self->query();

        my $header_type = $self->header_type();

	if ($header_type eq 'redirect') {
		return $q->redirect($self->header_props());
	} elsif ($header_type eq 'header' ) {
		return $q->header($self->header_props());
	}

        # croak() if we have an unknown header type
        croak ("Invalid header_type '$header_type'") unless ($header_type eq "none");

        # Do nothing if header type eq "none".
        return "";
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

  # In "WebApp.pm"...
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
  sub do_stuff { ... }
  sub do_more_stuff { ... }
  sub do_something_else { ... }
  1;


  ### In "webapp.cgi"...
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

   1;  # Perl requires this at the end of all modules


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
application can be organized into a specific set of "Run Modes."
Each Run Mode is roughly analogous to a single screen (a form, some 
output, etc.).  All the Run Modes are managed by a single "Application 
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

TMPL_PATH - This optional parameter adds value to the load_tmpl()
method (specified below).  This sets a path using HTML::Template's
C<path> option when you call load_tmpl() to get your HTML::Template
object.  This run-time parameter allows you to further encapsulate
instantiating templates, providing potential for more re-usability.
It can be either a scalar or an array reference of multiple paths.

PARAMS        - This parameter, if used, allows you to set a number 
of custom parameters at run-time.  By passing in different 
values in different instance scripts which use the same application 
module you can achieve a higher level of re-usability.  For instance, 
imagine an application module, "Mailform.pm".  The application takes 
the contents of a HTML form and emails it to a specified recipient.
You could have multiple instance scripts throughout your site which 
all use this "Mailform.pm" module, but which set different recipients
or different forms.

QUERY         - This optional parameter allows you to specify an 
already-created CGI.pm query object.  Under normal use, 
CGI::Application will instantiate its own CGI.pm query object.
Under certain conditions, it might be useful to be able to use
one which has already been created.


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
 
If the runmode dies for whatever reason, run() will see if you have set a
value for error_mode(). If you have, run() will call that method 
as a run mode.

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
    error_mode() - text scalar containing the error mode.
    run_modes() - hash table containing mode => function mappings.
    tmpl_path() - text scalar or array refefence containing path(s) to template files.

Your setup() method may call any of the instance methods of your application.
This function is a good place to define properties specific to your application
via the $webapp->param() method.

Your setup() method might be implemented something like this:

	sub setup {
		my $self = shift;
		$self->tmpl_path('/path/to/my/templates/');
		$self->start_mode('putform');
		$self->error_mode('my_error_rm');
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
setup() method is called.  This method provides an optional initialization
hook, which improves the object-oriented characteristics of 
CGI::Application.  The cgiapp_init() method receives, as its parameters,
all the arguments which were sent to the new() method.

An example of the benefits provided by utilizing this hook is 
creating a custom "application super-class" from which which all 
your CGI applications would inherit, instead of CGI::Application.

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


=item cgiapp_prerun()

If implemented, this method is called automatically right before the
selected run mode method is called.  This method provides an optional
pre-runmode hook, which permits functionality to be added at the point
right before the run mode method is called.  To further leverage this
hook, the value of the run mode is passed into cgiapp_prerun().
  
Another benefit provided by utilizing this hook is
creating a custom "application super-class" from which all
your CGI applications would inherit, instead of CGI::Application.

Consider the following:

  # In MySuperclass.pm:
  package MySuperclass;
  use base 'CGI::Application';
  sub cgiapp_prerun {
	my $self = shift;
	# Perform some project-specific init behavior
	# such as to implement run mode specific
	# authorization functions.
  }


  # In MyApplication.pm:
  package MyApplication;
  use base 'MySuperclass';
  sub setup { ... }
  sub teardown { ... }
  # The rest of your CGI::Application-based follows...  


By using CGI::Application and the cgiapp_prerun() method as illustrated, 
a suite of applications could be designed to share certain 
characteristics.  This has the potential for much cleaner code 
built on object-oriented inheritance.

It is also possible, within your cgiapp_prerun() method, to change the
run mode of your application.  This can be done via the prerun_mode()
method, which is discussed elsewhere in this POD.



=item cgiapp_postrun()

If implemented, this hook will be called after the run mode method
has returned its output, but before HTTP headers are generated.  This
will give you an opportunity to modify the body and headers before they 
are returned to the web browser.

A typical use for this hook is pipelining the output of a CGI-Application 
through a series of "filter" processors.  For example:

  * You want to enclose the output of all your CGI-Applications in 
    an HTML table in a larger page.

  * Your run modes return structured data (such as XML), which you
    want to transform using a standard mechanism (such as XSLT).

  * You want to post-process CGI-App output through another system,
    such as HTML::Mason.

  * You want to modify HTTP headers in a particular way across all
    run modes, based on particular criteria.

The cgiapp_postrun() hook receives a reference to the output from
your run mode method, in addition to the CGI-App object.  A typical
cgiapp_postrun() method might be implemented as follows:

  sub cgiapp_postrun {
    my $self = shift;
    my $output_ref = shift;

    # Enclose output HTML table
    my $new_output = "<table border=1>";
    $new_output .= "<tr><td> Hello, World! </td></tr>";
    $new_output .= "<tr><td>". $$output_ref ."</td></tr>";
    $new_output .= "</table>";

    # Replace old output with new output
    $$output_ref = $new_output;
  }


Obviously, with access to the CGI-App object you have full access to use all
the methods normally available in a run mode.  You could, for example, use
load_tmpl() to replace the static HTML in this example with HTML::Template.
You could change the HTTP headers (via header_type() and header_props()
methods) to set up a redirect.  You could also use the objects properties
to apply changes only under certain circumstance, such as a in only certain run
modes, and when a param() is a particular value.


=item cgiapp_get_query()

This method is called when CGI::Application retrieves the CGI query object.
The cgiapp_get_query() method loads CGI.pm via "require" and returns a 
CGI.pm query object.  The implementation is as follows:

  sub cgiapp_get_query {  
        my $self = shift;

        # Include CGI.pm and related modules
        require CGI;

        # Get the query object
        my $q = CGI->new();

        return $q;
  }

You may override this method if you wish to use a different query 
interface instead of CGI.pm.  Note, however, that your query interface 
must be compatible with CGI.pm, or you must wrap your chosen query
interface in a "wrapper" class to achieve compatibility.



=back


=head2 Application Module Methods

The following methods are inherited from CGI::Application, and are 
available to be called by your application within your Application
Module.  These functions are listed in alphabetical order.


=over 4

=item delete()
                                                                                                                                                             
    $webapp->delete('my_param');
                                                                                                                                                             
The delete() method is used to delete a parameter that was previously
stored inside of your application either by using the PARAMS hash that
was passed in your call to new() or by a call to the param() method.
This is similar to the delete() method of CGI.pm. It is useful if your
application makes decisions based on the existence of certain params that
may have been removed in previous sections of your app or simply to
clean-up your param()s.
                                                                                                                                                             

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

=item error_mode()

    $webapp->error_mode('my_error_rm');

The error_mode contains the name of a run mode to call in the event that the
planned run mode call fails C<eval>. No error_mode is defined by default. 
The death of your error_mode() run mode is not trapped, so you can also use
it to die in your own special way. 

=item get_current_runmode()

    $webapp->get_current_runmode();

The get_current_runmode() method will return a text scalar containing
the name of the run mode which is currently being executed.  If the 
run mode has not yet been determined, such as during setup(), this method
will return undef.

=item header_add()

    # add or replace the 'type' header
    $webapp->header_add( -type => 'image/png' );

    - or -

    # add an additional cookie
    $webapp->header_add(-cookie=>[$extra_cookie]);

The header_add() method is used to add one or more headers to the outgoing
response headers.  The parameters will eventuallly be passed on to the CGI.pm
header() method, so refer to the L<CGI> docs for exact usage details.  

Unlike calling header_props(), header_add() will preserve any existing
headers. If a scalar value is passed to header_add() it will replace
the existing value for that key.

If an array reference is passed as a value to header_add(), values in
that array ref will be appended to any existing values values for that key.
This is primarily useful for setting an additional cookie after one has already
been set.

=item header_props()

    $webapp->header_props(-type=>'image/gif',-expires=>'+3d');

The header_props() method expects a hash of CGI.pm-compatible 
HTTP header properties.  These properties will be passed directly 
to CGI.pm's header() or redirect() methods.  Refer to L<CGI> 
for exact usage details.  

Calling header_props will clobber any existing headers that have
previously set. 

To add additional headers later without clobbering the old ones,
see L<header_add()>.


B<IMPORTANT NOTE REGARDING HTTP HEADERS>

It is through the header_props() and header_add() method that you may modify the outgoing 
HTTP headers.  This is necessary when you want to set a cookie, set the mime 
type to something other than "text/html", or perform a redirect.  The 
header_props() method works in conjunction with the header_type() method.  
The value contained in header_type() determines if we use CGI::header() or 
CGI::redirect().  The content of header_props() is passed as an argument to 
whichever CGI.pm function is called.

Understanding this relationship is important if you wish to manipulate 
the HTTP header properly.


=item header_type([<'header' || 'redirect' || 'none'>])

    $webapp->header_type('redirect');

The header_type() method expects to be passed either 'header', 'redirect', or 'none'.
This method specifies the type of HTTP headers which should be sent back to 
the browser.  If not specified, defaults is 'header'.  See the 
header section of L<CGI> for details.

To perform a redirect using CGI::Application (and CGI.pm), you would
do the following:

  sub some_redirect_mode {
    my $self = shift;
    my $new_url = "http://site/path/doc.html";
    $self->header_type('redirect');
    $self->header_props(-url=>$new_url);
    return "Redirecting to $new_url";
  }

If you wish to suppress HTTP headers entirely (as might be the case if 
you're working in a slightly more exotic environment), you can set
header_type() to "none".  This will completely hide headers.


=item load_tmpl()

    my $tmpl_obj = $webapp->load_tmpl('some.tmpl');

This method takes the name of a template file and returns an 
HTML::Template object.  The HTML::Template->new_file() constructor
is used for create the object.  Refer to L<HTML::Template> for specific usage
of HTML::Template.

If tmpl_path() has been specified, load_tmpl() will set the
HTML::Template C<path> option to the path(s) provided.  This further
assists in encapsulating template usage.

The load_tmpl() method will pass any extra parameters sent to it directly to 
HTML::Template->new_file().  This will allow the HTML::Template object to be 
further customized:

    my $tmpl_obj = $webapp->load_tmpl('some_other.tmpl', 
         die_on_bad_params => 0,
         cache => 1
    );

If your application requires more specialized behavior than this, you are
encouraged to override load_tmpl() by implementing your own load_tmpl() 
in your CGI::Application sub-class application module.


=item mode_param()

 # Name the CGI form parameter that contains the run mode name.
 # This is the the default behavior, and is often sufficient.
 $webapp->mode_param('rm');

 # Set the run mode name directly from a code ref 
 $webapp->mode_param(\&some_method);
 
 # Alternate interface, which allows you to set the run 
 # mode name directly from $ENV{PATH_INFO}.
 $webapp->mode_param( 
 	path_info=> 1, 
 	param =>'rm'
 );

This accessor/mutator method is generally called in the setup() method.  
It is used to help determine the run mode to call. There are three options for calling it. 

 $webapp->mode_param('rm');

Here, a CGI form parameter is named that will contain the name of the run mode
to use. This is the default behavior, with 'rm' being the parameter named used. 

 $webapp->mode_param(\&some_method);

Here a code reference is provided. It will return the name of the run mode
to use directly. Example:

 sub some_method {
   my $self = shift;
   return 'run_mode_x';
 }

This would allow you to programmatically set the run mode based on arbitrary logic.

 $webapp->mode_param( 
 	path_info=> 1, 
 	param =>'rm'
 );

This syntax allows you to easily set the run mode from $ENV{PATH_INFO}.  It
will try to set the run mode from the first part of $ENV{PATH_INFO} (before the
first "/"). To specify that you would rather get the run name from the 2nd
part of $ENV{PATH_INFO}:

 $webapp->mode_param( path_info=> 2 );

This also demonstrates that you don't need to pass in the C<param> hash key. It will
still default to C<rm>.

If no run mode is found in $ENV{PATH_INFO}, it will fall back to looking in the
value of a the CGI form field defined with 'param', as described above.  This
allows you to use the convenient $ENV{PATH_INFO} trick most of the time, but
also supports the edge cases, such as when you don't know what the run mode
will be ahead of time and want to define it with JavaScript. 

B<More about $ENV{PATH_INFO}>.

Using $ENV{PATH_INFO} to name your run mode creates a clean seperation between
the form variables you submit and how you determine the processing run mode. It
also creates URLs that are more search engine friendly. Let's look at an
example form submission using this syntax:

	<form action="/cgi-bin/instance.cgi/edit_form" method=post>
		<input type="hidden" name="breed_id" value="4">
	
Here the run mode would be set to "edit_form". Here's another example with a
query string:

	/cgi-bin/instance.cgi/edit_form?breed_id=2

This demostrates that you can use $ENV{PATH_INFO} and a query string together
without problems. $ENV{PATH_INFO} is defined as part of the CGI specification
should be supported by any web server that supports CGI scripts. 

=cut 

sub mode_param {
	my $self = shift;
	my $mode_param;

	# First use?  Create new __MODE_PARAM
	$self->{__MODE_PARAM} = 'rm' unless (exists($self->{__MODE_PARAM}));

	my %p;
	# expecting a scalar or code ref
	if ((scalar @_) == 1) {
		$mode_param = $_[0];
	}
	# expecting hash style params
	else {
  		croak("CGI::Application->mode_param() : You gave me an odd number of parameters to mode_param()!")
    		unless ((@_ % 2) == 0);
		%p = @_;
		$mode_param = $p{param};

		if ($p{path_info}) {
			my $pi = $ENV{PATH_INFO};
			# computer scientists like to start counting from zero. 
			my $idx = $p{path_info} - 1;

			# remove the leading slash
			$pi =~ s!^/!!;

			# grab the requested field location
			$pi = (split q'/', $pi)[$idx] || '';

			$mode_param = (length $pi) ?  { run_mode => $pi } : $mode_param;
		}

	}

	# If data is provided, set it
	if (defined($mode_param)) {
		$self->{__MODE_PARAM} = $mode_param;
	}

	return $self->{__MODE_PARAM};
}

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

The param() method also allows you to set a bunch of parameters at once
by passing in a hash (or hashref):

    $webapp->param(
        'key1' => 'val1',
        'key2' => 'val2',
        'key3' => 'val3',
    );

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
greatly increasing your application's re-usability.

=item prerun_mode()

    $webapp->prerun_mode('new_run_mode');

The prerun_mode() method is an accessor/mutator which can be used within 
your cgiapp_prerun() method to change the run mode which is about to be executed.
For example, consider:

  # In WebApp.pm:
  package WebApp;
  use base 'CGI::Application';
  sub cgiapp_prerun {
	my $self = shift;

	# Get the web user name, if any
	my $q = $self->query();
	my $user = $q->remote_user();

	# Redirect to login, if necessary
	unless ($user) {
		$self->prerun_mode('login');
	}
  }


In this example, the web user will be forced into the "login" run mode
unless they have already logged in.  The prerun_mode() method permits
a scalar text string to be set which overrides whatever the run mode
would otherwise be.

The use of prerun_mode() within cgiapp_prerun() differs from setting 
mode_param() to use a call-back via subroutine reference.  It differs 
because cgiapp_prerun() allows you to selectively set the run mode based 
on some logic in your cgiapp_prerun() method.  The call-back facility of 
mode_param() forces you to entirely replace CGI::Application's mechanism 
for determining the run mode with your own method.  The prerun_mode()
method should be used in cases where you want to use CGI::Application's
normal run mode switching facility, but you want to make selective
changes to the mode under specific conditions.

B<Note:>  The prerun_mode() method may ONLY be called in the context of
a cgiapp_prerun() method.  Your application will die() if you call 
prerun_mode() elsewhere, such as in setup() or a run mode method.

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
method supports passing in your existing query object on construction using
the QUERY attribute.


=item run_modes()

    $webapp->run_modes('mode1' => 'some_sub_by_name', 'mode2' => \&some_other_sub_by_ref);

This accessor/mutator expects a hash which specifies the dispatch table for the 
different CGI states.  The run() method uses the data in this table 
to send the CGI to the correct function as determined by reading 
the CGI parameter specified by mode_param() (defaults to 'rm' for "Run Mode").  
These functions are referred to as "run mode methods".

The hash table set by this method is expected to contain the mode 
name as a key.  The value should be either a hard reference (a subref) 
to the run mode method which you want to be called when the CGI enters 
the specified run mode, or the name of the run mode method to be called:

    'mode_name_by_ref'  => \&mode_function
    'mode_name_by_name' => 'mode_function'

The run mode method specified is expected to return a block of text 
(e.g.: HTML) which will eventually be sent back to the web browser.  
The your run mode method may return its block of text as a scalar 
or a scalar-ref.

An advantage of specifying your run mode methods by name instead of 
by reference is that you can more easily create derivative application 
using inheritance.  For instance, if you have a new application which is
exactly the same as an existing application with the exception of one
run mode, you could simply inherit from that other application and override
the run mode method which is different.  If you specified your run mode 
method by reference, your child class would still use the function
from the parent class.

An advantage of specifying your run mode methods by reference instead of by name 
is performance.  Dereferencing a subref is faster than eval()-ing 
a code block.  If run-time performance is a critical issue, specify
your run mode methods by reference and not by name.  The speed differences
are generally small, however, so specifying by name is preferred.

The run_modes() method may be called more than once.  Additional values passed 
into run_modes() will be added to the run modes table.  In the case that an 
existing run mode is re-defined, the new value will override the existing value.
This behavior might be useful for applications which are created via inheritance 
from another application, or some advanced application which modifies its
own capabilities based on user input.

The run_modes() method also supports a second interface for designating 
run modes and their methods:  Via array reference:

    $webapp->run_modes([ 'mode1', 'mode2', 'mode3' ]);

This is the same as the following, via hash:

    $webapp->run_modes(
        'mode1' => 'mode1',
        'mode2' => 'mode2',
        'mode3' => 'mode3'
    );

Often, it makes good organizational sense to have your run modes map to
methods of the same name.  The array-ref interface provides a shortcut 
to that behavior while reducing verbosity of your code.

Note that another importance of specifying your run modes in either a 
hash or array-ref is to assure that only those Perl methods which are 
specifically designated may be called via your application.  Application
environments which don't specify allowed methods and disallow all others
are insecure, potentially opening the door to allowing execution of 
arbitrary code.  CGI::Application maintains a strict "default-deny" stance
on all method invocation, thereby allowing secure applications
to be built upon it.

B<IMPORTANT NOTE ABOUT RUN MODE METHODS>

Your application should *NEVER* print() to STDOUT.
Using print() to send output to STDOUT (including HTTP headers) is 
exclusively the domain of the inherited run() method.  Breaking this 
rule is a common source of errors.  If your program is erroneously 
sending content before your HTTP header, you are probably breaking this rule.


B<THE RUN MODE OF LAST RESORT: "AUTOLOAD">

If CGI::Application is asked to go to a run mode which doesn't exist
it will usually croak() with errors.  If this is not your desired 
behavior, it is possible to catch this exception by implementing 
a run mode with the reserved name "AUTOLOAD":

  $self->run_modes(
	"AUTOLOAD" => \&catch_my_exception
  );

Before CGI::Application calls croak() it will check for the existence 
of a run mode called "AUTOLOAD".  If specified, this run mode will in 
invoked just like a regular run mode, with one exception:  It will 
receive, as an argument, the name of the run mode which invoked it:

  sub catch_my_exception {
	my $self = shift;
	my $intended_runmode = shift;

	my $output = "Looking for '$intended_runmode', but found 'AUTOLOAD' instead";
	return $output;
  } 

This functionality could be used for a simple human-readable error 
screen, or for more sophisticated application behaviors.


=item start_mode()

    $webapp->start_mode('mode1');

The start_mode contains the name of the mode as specified in the run_modes() 
table.  Default mode is "start".  The mode key specified here will be used 
whenever the value of the CGI form parameter specified by mode_param() is 
not defined.  Generally, this is the first time your application is executed.

=item tmpl_path()

    $webapp->tmpl_path('/path/to/some/templates/');

This access/mutator method sets the file path to the directory (or directories)
where the templates are stored.  It is used by load_tmpl() to find the template
files, using HTML::Template's C<path> option. To set the path you can either
pass in a text scalar or an array reference of multiple paths.

=back

=head2 Testing
                                                                                                                                                             
CGI::Application currently has no built-in testing methodology but we leave that
up to you. There are many testing structures and frameworks that are available for
testing Perl modules (ie, Test::Harness, Test::More). There are large numbers
of tools and frameworks for testing live web applications (WWW::Mechanize, HTTP::Test,
Apache::Test). We encourage you to look around CPAN and find the one that
best meets your needs.
                                                                                                                                                             
Since most of the module level testing frameworks require the output that is sent to
STDOUT be of a certain format, and since CGI::Application will print the output of it's
run modes directly to STDOUT this could cause problems. To avoid this simple set the
environment variable 'CGI_APP_RETURN_ONLY' to true and you can catch your output and
test it and then print your own message to STDOUT. For example
                                                                                                                                                             
        $ENV{CGI_APP_RETURN_ONLY} = 1;
        $output = $webapp->run();
                                                                                                                                                             
        #perform whatever test on the output that you want and then print to STDOUT
        if($output =~ /GOOD/){
                print "ok 11\n";
        } else {
                print "not ok 11\n";
        }

=head1 PLUG-INS

CGI::Application has a plug-in architecture that is easy to use and easy
to develop new plug-ins for.

=head2 Existing plug-ins

Here are some plug-ins that have already been developed for
CGI::Application. For a current complete list, please consult CPAN:

http://search.cpan.org/search?query=CGI%3A%3AApplication%3A%3APlugin&mode=module

=over 4

=item *

L<CGI::Application::Plugin::Config::Simple> - Integration with Config::Simple.

=item *

L<CGI::Application::Plugin::ConfigAuto> - Integration with Config::Auto.

=item *

L<CGI::Application::Plugin::DBH> - Integration with DBI.

=item *

L<CGI::Application::Plugin::Session> - Integration with L<CGI::Session>

=item * 

L<CGI::Application::Plugin::TT> - Use L<Template::Toolkit> as an alternative to HTML::Template.

=item *

L<CGI:::Application::Plugin::ValidateRM> - Integration with Data::FormValidator and HTML::FillInForm

=back

Consult each plug-in for the exact usage syntax. 


=head2 Writing Plug-ins

Writing plug-ins is simple. Simply create a new package, and export the
methods that you want to become part of a CGI::Application project. See
L<CGI::Application::Plugin::ValidateRM> for an example.

You only need to keep in mind that your extension should "play well with
others". The method names exported should be unique. Also, additions to
the CGI::Application object should be designed not to conflict with other
potentional plug-ins. For that reason, it's recommended that you add a
a hash key to the CGI::Application which reflects the name of your
plug-in, such as:

 $self->{'Config::Simple'}

=head1 COMMUNITY

There a couple of primary resources available for those who wish to learn more
about CGI::Application and discuss it with others.

B<Wiki>

This is a community built and maintained resource that anyone is welcome to
contribute to. It contains a number of articles of its own and links
to many other CGI::Application related pages:

L<http://www.cgi-app.org>

B<Support Mailing List>

If you have any questions, comments, bug reports or feature suggestions, 
post them to the support mailing list!  To join the mailing list, simply
send a blank message to "cgiapp-subscribe@lists.erlbaum.net".

=head1 SEE ALSO

L<CGI>, L<HTML::Template>, L<CGI::Application::ValidateRM> perl(1)


=head1 AUTHOR

Jesse Erlbaum <jesse@erlbaum.net>

Mark Stosberg has served as a co-maintainer since version 3.2, with the help of
the numerous contributors documented in the Changes file.

B<More Reading>

If you're interested in finding out more about CGI::Application, the 
following article is available on Perl.com:

    Using CGI::Application
    http://www.perl.com/pub/a/2001/06/05/cgi.html

Thanks to Simon Cozens and the O'Reilly network for publishing this
article, and for the incredible value they provide to the Perl
community!


=head1 CREDITS

CGI::Application is developed by The Erlbaum Group, a software
engineering and consulting firm in New York City.  If you are looking
for a company to develop your web site or individual developers to 
augment your team please contact us:

    The Erlbaum Group, LLC
    826 Broadway, Suite 933
    New York, NY 10003

    Phone: 212-684-6161
    Fax: 212-684-6226
    Email: info@erlbaum.net
    Web: http://www.erlbaum.net


Thanks to Vanguard Media (http://www.vm.com) for funding the initial 
development of this library and for encouraging me to release it to 
the world.

Many thanks to Sam Tregar (author of the most excellent 
HTML::Template module!) for his innumerable contributions 
to this module over the years, and most of all for getting 
me off my ass to finally get this thing up on CPAN!

Many other people have contributed specific suggestions or patches,
which are documented in the C<Changes> file.

Thanks also to all the members of the CGI-App mailing list!
Your ideas, suggestions, insights (and criticism!) have helped
shape this module immeasurably.  (To join the mailing list, simply
send a blank message to "cgiapp-subscribe@lists.erlbaum.net".)

=head1 LICENSE

CGI::Application : Framework for building reusable web-applications
Copyright (C) 2000-2003 Jesse Erlbaum <jesse@erlbaum.net>

This module is free software; you can redistribute it and/or modify it
under the terms of either:

a) the GNU General Public License as published by the Free Software
Foundation; either version 1, or (at your option) any later version,

or

b) the "Artistic License" which comes with this module.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
the GNU General Public License or the Artistic License for more details.

You should have received a copy of the Artistic License with this
module, in the file ARTISTIC.  If not, I'll be glad to provide one.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
USA


=cut

