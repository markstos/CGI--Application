package PSGI::Application;
use Carp;
use strict;
use Try::Tiny;
use Any::Moose;
use Any::Moose 'Util::TypeConstraints';

our $VERSION = '4.90_01';
our $AUTHORITY = 'cpan:MARKSTOS';

has 'start_mode' => (
    is       => 'rw',
    isa      => 'Str',
    default  => 'start',
    init_arg => undef,
);
has 'error_mode'=> (
  is       => 'rw',
  isa      => 'Maybe[Str]',
  init_arg => undef,
);

# Allow tmpl_path to be a str or arrayref
subtype 'PSGI::Application::ArrayRef',
    as 'ArrayRef[Str]';

coerce 'PSGI::Application::ArrayRef',
    from 'Str',
    via { [ $_ ] };

has 'tmpl_path' => (
  is        => 'rw',
  isa       => 'PSGI::Application::ArrayRef',
  default   => '',
  init_arg  => 'TMPL_PATH',
  coerce    => 1,
  auto_deref=> 1,
);
has '_current_runmode' => (
  is       => 'rw',
  isa      => 'Str',
  init_arg => undef,
  reader   => 'get_current_runmode',
  writer   => '_set_current_runmode',
);

# Lock prerun_mode from being changed until prerun()
has '_prerun_mode_locked' => (
  is       => 'rw' ,
  isa      => 'Bool',
  default  => 1,
  init_arg => undef,
);
# accessor/mutator for the getting/setting the runmode in cgiapp_prerun
# trigger is to ensure you're only doing it while in cgiapp_prerun
has '_prerun_mode' => (
    is => 'rw',
    isa => 'Str',
    default => '',
    init_arg => undef,
);

has '_mode_param' => (
    is         => 'rw',
    isa        => 'Str | CodeRef | HashRef',
    lazy       => 1,
    default    => 'rm',
    init_arg => undef,
);
has 'header_type' => (
    is      => 'rw',
    isa     => enum([qw[ header redirect none ]]),
    default => 'header',
);
has '_header_props' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
    init_arg => undef,
);
has '_params' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { +{} },
    init_arg => 'PARAMS',
);

has 'req' => (
    is       => 'rw',
    isa      => 'Object',
#    lazy     => 1,
#    builder  => 'get_request',
    init_arg => 'REQUEST',
);
# This is wrong, because no $env is passed in.
# This could possibly be solved by storing $env in $self->env, so we could use CGI::PSGI->new($self->env)
#sub get_req { require CGI::PSGI; CGI::PSGI->new }





# These could be implemented with MooseX::ClassAttributes, but that wouldn't work in Mouse, and would have
# a big start-up penalty.
my %CLASS_CALLBACKS = (
#	hook name          package                 sub
	init      => { 'PSGI::Application' => [ 'init'    ] },
	prerun    => { 'PSGI::Application' => [ 'prerun'  ] },
	postrun   => { 'PSGI::Application' => [ 'postrun' ] },
	teardown  => { 'PSGI::Application' => [ 'teardown'] },
	load_tmpl => { },
	error     => { },
);

###################################
####  INSTANCE SCRIPT METHODS  ####
###################################

sub BUILD {
    my ($self, @args) = @_;

	# Call init() method, which may be implemented in the sub-class.
	# Pass all constructor args forward.  This will allow flexible usage
	# down the line.
	$self->call_hook('init', @args);

	# Call setup() method, which should be implemented in the sub-class!
	$self->setup();

	return $self;
}

sub _get_runmode {
	my $self     = shift;
	my $rm_param = shift;

   # Support call-back instead of CGI mode param
    my $rm = ref($rm_param) eq 'CODE' ? $rm_param->($self)             # Get run mode from subref
           : ref($rm_param) eq 'HASH' ? $rm_param->{run_mode}          # support setting run mode from PATH_INFO
           :                            $self->req->param($rm_param) # Get run mode from request object
           ;

           #warn "rm param: $rm got turned into $rm";

	# If $rm undefined, use default (start) mode
	$rm = $self->start_mode unless defined($rm) && length($rm);

	return $rm;
}

sub _get_runmeth {
	my $self = shift;
	my $rm   = shift;

    my $runmode_method;

    my $is_autoload = 0; # flag whether or not we end up using AUTOLOAD

    my %runmodes = $self->run_modes();

    # Default: runmode is stored and is not an autoload method
    return ( $runmodes{$rm}, $is_autoload)
        if exists $runmodes{$rm};

    # Look for run mode "AUTOLOAD" before dieing
    confess("No such run mode '$rm'")
        unless exists $runmodes{'AUTOLOAD'};

    $runmode_method = $runmodes{'AUTOLOAD'};
    $is_autoload = 1;

    return ($runmode_method, $is_autoload);
}



sub _get_body {
	my $self  = shift;
	my $rm    = shift;

	my ($rmeth, $is_autoload) = $self->_get_runmeth($rm);

	my $body;
	try {
        $body = $is_autoload
              ? $self->$rmeth($rm)
              : $self->$rmeth()
              ;
	} catch {
		my $error = $_;
		$self->call_hook('error', $error);
		if (my $em = $self->error_mode) {
			$body = $self->$em( $error );
		}
        else {
			croak("Error executing run mode '$rm': $error");
		}
	};

	# Make sure that $body is not undefined (suppress 'uninitialized value'
	# warnings)
	return defined $body ? $body : '';
}


sub run {
	my $self = shift;
	my $req = $self->req();

	my $rm_param = $self->mode_param();

    #warn "rm param from mode param: $rm_param";

	my $rm = $self->_get_runmode($rm_param);

    # warn "rm selected was: $rm";

	# Set get_current_runmode() for access by user later
    $self->_set_current_runmode($rm);

	# Allow prerun_mode to be changed
    $self->_prerun_mode_locked(0);

	# Call PRE-RUN hook, now that we know the run mode
	# This hook can be used to provide run mode specific behaviors
	# before the run mode actually runs.
 	$self->call_hook('prerun', $rm);

	# Lock prerun_mode from being changed after prerun()
    $self->_prerun_mode_locked(1);

	# If prerun_mode has been set, use it!
	my $prerun_mode = $self->prerun_mode();
	if (length($prerun_mode)) {
		$rm = $prerun_mode;
        $self->_set_current_runmode($rm)
	}

	# Process run mode!
	my $body = $self->_get_body($rm);

	# Support scalar-ref for body return
	$body = $$body if ref $body eq 'SCALAR';

	# Call postrun() hook
	$self->call_hook('postrun', \$body);

    my $return_value;
    my ($status, $headers) = $self->_send_psgi_headers();
    $return_value = [ $status, $headers, [ $body ]];

	# clean up operations
	$self->call_hook('teardown');

	return $return_value;
}


sub psgi_app {
    my $class = shift;
    my $args_to_new = shift;

    return sub {
        my $env = shift;

        if (not defined $args_to_new->{REQUEST}) {
            require CGI::PSGI;
            $args_to_new->{REQUEST} = CGI::PSGI->new($env);
        }

        my $webapp = $class->new($args_to_new);
        return $webapp->run;
    }
}

############################
####  OVERRIDE METHODS  ####
############################

sub init {
	my $self = shift;
	my @args = (@_);

	# Nothing to init, yet!
}


sub prerun {
	my $self = shift;
	my $rm = shift;

	# Nothing to prerun, yet!
}


sub postrun {
	my $self = shift;
	my $bodyref = shift;

	# Nothing to postrun, yet!
}


sub setup {
	my $self = shift;
}


sub teardown {
	my $self = shift;

	# Nothing to shut down, yet!
}




######################################
####  APPLICATION MODULE METHODS  ####
######################################



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

	my $props;

	# If data is provided, set it!
	if (scalar(@data)) {
        if ($self->header_type eq 'none') {
		    warn "header_props called while header_type set to 'none', headers will NOT be sent!"
        }
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
				my $existing_val = $self->_header_props->{$key_set_to_aref};
				next unless defined $existing_val;
				my @existing_val_array = (ref $existing_val eq 'ARRAY') ? @$existing_val : ($existing_val);
				$props->{$key_set_to_aref} = [ @existing_val_array, @{ $props->{$key_set_to_aref} } ];
			}

			$self->_header_props(+{ %{ $self->_header_props }, %$props });
		}
		# Set new headers, clobbering existing values
		else {
			$self->_header_props($props);
		}

	}

	# If we've gotten this far, return the value!
	return (%{ $self->_header_props });
}

sub param {
	my $self = shift;
	my (@data) = (@_);

	my $rp = $self->_params;

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

has '_run_modes' => (
    # traits are supported by both Mouse and Moose, but not Any::Moose, so we avoid them for now.
    # traits      => [ qw/Hash/ ],
    is          => 'rw',
    isa         => 'HashRef',
    lazy        => 1,
    init_arg    => undef,
    predicate   => '_any_run_modes',
    builder     => 'default_run_modes',
);
sub default_run_modes {
    my $self = shift;
    my %default_run_modes = (
        'start' => sub  { 'Hello World' }
    );
    return \%default_run_modes;
}

sub run_modes {
	my $self = shift;
	my (@data) = (@_);

	my $rr_m = $self->_run_modes();

	# If data is provided, set it!
	if (scalar(@data)) {
		# Is it a hash, hash-ref, or array-ref?
		if (ref($data[0]) eq 'HASH') {
			# Make a copy, which augments the existing contents (if any)
			%$rr_m = (%$rr_m, %{$data[0]});
		} elsif (ref($data[0]) eq 'ARRAY') {
			# Convert array-ref into hash table
			for my $rm (@{$data[0]}) {
				$rr_m->{$rm} = $rm;
			}
		} elsif ((scalar(@data) % 2) == 0) {
			# It appears to be a possible hash (even # of elements)
			%$rr_m = (%$rr_m, @data);
		} else {
			croak("Odd number of elements passed to run_modes().  Not a valid hash");
		}
	}

    $self->_run_modes($rr_m);

	# If we've gotten this far, return the value!
	return (%$rr_m);
}

sub prerun_mode {
    my $self = shift;
    my $mode = shift;

    if (defined $mode) {
        if ( $self->_prerun_mode_locked() ) {
            confess("prerun_mode() can only be called within cgiapp_prerun()!  Error")
        }
        else {
            $self->_prerun_mode($mode) if defined $mode;
        }
    }

    return $self->_prerun_mode;
}


###########################
####  PRIVATE METHODS  ####
###########################



# return a 2 element array modeling the first PSGI redirect values: status code and arrayref of header pairs
sub _send_psgi_headers {
    my $self = shift;
    my $req   = $self->req;
    my $type = $self->header_type;

    # warn "in _send_psgi_headers";
    # use Data::Dumper;
    # warn Dumper ('props',$self->header_props );

    return
        $type eq 'redirect' ? $req->psgi_redirect( $self->header_props )
      : $type eq 'header'   ? $req->psgi_header  ( $self->header_props )
      : $type eq 'none'     ? (200, [] )
      : croak "Invalid header_type '$type'"

}

################################################
# originally from CAP::Plugins::Forward by Michael Graham
#
# forwards from one runmode to another while maintaing the current runmode
# state.  This is instead of calling $self->other_run_mode in a runmode.
sub forward {
    my $self     = shift;
    my $run_mode = shift;

    # XXX Let's find a better way to handle this. 
    if ($CGI::Application::Plugin::AutoRunmode::VERSION) {
        if (CGI::Application::Plugin::AutoRunmode->can('is_auto_runmode')) {
            if (CGI::Application::Plugin::AutoRunmode::is_auto_runmode($self, $run_mode)) {
                $self->run_modes( $run_mode => $run_mode);
            }
        }
    }

    my $rm_map = $self->run_modes;

    confess "forward: run mode $run_mode does not exist"
        unless exists $rm_map->{$run_mode};

    my $method = $rm_map->{$run_mode};

    if ($self->can($method) || ref $method eq 'CODE') {
        $self->_set_current_runmode( $run_mode );
        $self->call_hook('forward_prerun');
        return $self->$method(@_);
    }

    confess "forward: target method $method of run mode $run_mode does not exist";
}

##############################
# originally from CGI::Application::Plugin::Forward by Cees Hek
#
# all in one magical redirect
sub redirect {
    my $self     = shift;
    my ($location, $status) = (@_);

    try {
        $self->run_modes( dummy_redirect => sub { } );
        $self->prerun_mode('dummy_redirect');
    }
    catch { }; # don't care what happens.


    $self->header_add( -location => $location );
    $self->header_add( -status => $status ) if $status;
    $self->header_type('redirect');

    return;

}



1;

=head1 NAME

PSGI::Application - Lightweight web framework using PSGI and Any::Moose

=head1 SYNOPSIS

  # In "WebApp.pm"...
  package WebApp;

  # using Mouse or Moose in your app is optional, but recommended.
  use Any::Moose;
  extends 'PSGI::Application';

  # ( setup() can even be skipped for common cases. See docs below. )
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


  ### In "webapp.psgi"...
  use WebApp;
  my $webapp = WebApp->new();
  $webapp->run();

  ### Or, in a PSGI file, webapp.psgi
  use WebApp;
  WebApp->psgi_app();

=head1 INTRODUCTION

PSGI::Application is a lightweight framework suitable for a range of
applications, from running small projects in CGI, to using it as the foundation
for large custom projects running high-traffic websites.

=head2 PSGI Support

PSGI::Application provides first-class L<< PSGI >> support. This has a couple
major benefits: First, you don't have to worry about many details about the
environment you are running in. There are L<< Plack >> libraries which can take
care of much that for you. Second, PSGI support provides you access to dozens of
existing L<< Middlewares|http://search.cpan.org/search?query=Plack%3A%3AMiddleware&mode=module >> which are compatible with multiple frameworks and
enhance your applications.

Also, you have the option to write a PSGI-compatible Middleware instead of a
native framework plugin. You've then got increased value through
framework-independence, and more potential users and contributors than only
those that use PSGI::Application.


=head2 Mouse / Moose native

PSGI::Application uses L<< Any::Moose >>, which means it will work with
the lightweight L<< Mouse >> or the full-featured L<< Moose >> libraries. 

Using either is optional in your own sub-class, but recommended. In particular,
L<< Moose Roles|Mouse::Manual::Roles >> provide another powerful way to extend
your application. Roles automatically compose attributes into "new()", allowing
a natural way for a role-based plugin to receive configuration details. You'll
find a number of existing Roles on CPAN that you could extend your project
with. In some cases, roles might be usefully shared with other objects you
might create, or also with other web frameworks. For example, think of easily
making a database handle available to objects, or a C<< config() >> method to
access your project configuration method.

=head2 Compatible with CGI::Application and plugins

L<< PSGI::Application >> evolved from L<< CGI::Application >>, a popular
framework with over a decade history, and over 80 L<<published plugins|
http://search.cpan.org/search?query=CGI%3A%3AApplication%3A%3APlugin&mode=dist
>>. As a forward-looking project, PSGI::Application makes a number of breaking
changes (documented below in L<< COMPATIBILITY WITH CGI::Application >>), but
recognizes the fundamental design of CGI::Application is sound and remains useful.
Through L<< PSGI::Application::Compat >>, much existing code designed for
CGI::Application will be able to run on PSGI::Application with few or no
changes.

This break from the past is also an invitation to plugin authors to make
non-compatible improvements to their own plugins, or to take advantage of
possibility re-implementing them as PSGI middleware or a Moose role.

=head1 USAGE EXAMPLE

Imagine you have to write an application to search through a database
of widgets.  Your application has three screens:

   1. Search form
   2. List of results
   3. Detail of a single record

To write this application using PSGI::Application you will create two files:

   1. WidgetView.pm -- Your "Application Module"
   2. widgetview.psgi -- Your "Instance Script"

The Application Module contains all the code specific to your
application functionality, and it exists outside of your web server's
document root, somewhere in the Perl library search path.

The Instance Script is what is actually called by your web server.  It is
a very small, simple file which simply creates an instance of your
application and calls an inherited method, run().  Following is the
entirety of "widgetview.psgi":

   #!/usr/bin/perl -w
   use WidgetView;
   WidgetView->psgi_app();

As you can see, widgetview.psgi simply "uses" your Application module
(which implements a Perl package called "WidgetView").  Your Application Module,
"WidgetView.pm", is somewhat more lengthy:

   package WidgetView;
   use Mouse;
   extends 'PSGI::Application';
   use strict;

   # Needed for our database connection
   use CGI::Application::Plugin::DBH;

   sub setup {
	my $self = shift;
	$self->start_mode('mode1');
	$self->run_modes(
		'mode1' => 'showform',
		'mode2' => 'showlist',
		'mode3' => 'showdetail'
	);

	# Connect to DBI database, with the same args as DBI->connect();
     $self->dbh_config();
   }

   sub teardown {
	my $self = shift;

	# Disconnect when we're done, (Although DBI usually does this automatically)
	$self->dbh->disconnect();
   }

   sub showform {
	my $self = shift;

	# Get the HTTP request object
	my $req = $self->req();

    # ( Usually you would use a templating system instead. )
	return qq{
    <html>
        <head>
            <title>Widget Search Form</title>
        </head>
        <body>
            <form action="/path/to/script.psgi/mode2>
                <input type="text" name="widgetcode">
                <input type="submit">
            </form>
        </body>
    </html>
    };
   }

   sub showlist {
	my $self = shift;

	# Get our database connection
	my $dbh = $self->dbh();

	# Get HTTP request object
	my $req = $self->req();
	my $widgetcode = $req->param("widgetcode");

    # ( Again, usually templates are used instead )
	my $output = '';
	$output .= qq{
        <html><head><title>List of Matching Widgets</title></head>
    };

	## Do a bunch of stuff to select "widgets" from a DBI-connected
	## database which match the user-supplied value of "widgetcode"
	## which has been supplied from the previous HTML form via a
	## request object.
	##
	## Each row will contain a link to a "Widget Detail" which
	## provides an anchor tag, as follows:
	##
	##   "widgetview.psgi/mode3?widgetid=XXX"
	##
	##  ...Where "XXX" is a unique value referencing the ID of
	## the particular "widget" upon which the user has clicked.

	$output .= '</html>';

	return $output;
   }

   sub showdetail {
	my $self = shift;

	# Get our database connection
	my $dbh = $self->dbh();

	# Get HTTP request object
	my $req = $self->req();
	my $widgetid = $req->param("widgetid");

	my $output = '';
	$output .= qq{
        <html><head><title>Widget Detail</title></head>
    };

	## Do a bunch of things to select all the properties of
	## the particular "widget" upon which the user has
	## clicked.  The key id value of this widget is provided
	## via the "widgetid" property, accessed via the request object.

	$output .= '</html>';

	return $output;
   }

   1;  # Perl requires this at the end of all modules


PSGI::Application takes care of implementing the new() and the run()
methods.

=head1 ABSTRACT

The guiding philosophy behind PSGI::Application is that a web-based
application can be organized into a specific set of "Run Modes."
Each Run Mode is roughly analogous to a single screen (a form, some
output, etc.).  Groups of related Run Modes are managed by a single "Application
Module" which is a Perl module.  In your web server's document space
there is an "Instance Script" which is called by the web server.

=head1 DESCRIPTION

It is intended that your Application Module will be implemented as a sub-class
of PSGI::Application. This is done simply as follows:

    package My::App;
    use Any::Moose;
    extends 'PSGI::Application';

B<Notation and Conventions>

For the purpose of this document, we will refer to the
following conventions:

  WebApp.pm   The Perl module which implements your Application Module class.
  WebApp      Your Application Module class; a sub-class of PSGI::Application.
  webapp.psgi The Instance Script which implements your Application Module.
  $webapp     An instance (object) of your Application Module class.
  $c          Same as $webapp, used in instance methods to pass around the
              current object. (Sometimes referred as "$self" in other code)

=head2 Instance Script Methods

By inheriting from PSGI::Application you have access to a
number of built-in methods.  The following are those which
are expected to be called from your Instance Script.

=head3 psgi_app()

 $psgi_coderef = WebApp->psgi_app({ ... args to new() ... });

The simplest way to create and return a PSGI-compatible coderef. Pass in
arguments to a hashref just as would to C<< new() >>. This return a
PSGI-compatible coderef, currently using L<CGI:::PSGI> as the request object.
To use a different req object, construct your own object using C<<
run_as_psgi() >>, as shown below.

B<WARNING> We plan to replace CGI::PSGI with a new request object in the future,
which likely won't be 100% compatible. You could continue to use L<CGI::PSGI>
by specifying it explicitly.

=head3 new()

A constructor which returns an object to handle a single request/response
cycle.  Optionally, new() may take a set of parameters as key => value pairs:

    my $webapp = WebApp->new(
        TMPL_PATH => 'App/',
        PARAMS => {
            'custom_thing_1' => 'some val',
            'another_custom_thing' => [qw/123 456/]
        }
    );

This method may take some specific parameters:

B<TMPL_PATH> - This optional parameter defines a path to a directory of
templates.  This is used by the load_tmpl() method provided by
L<PSGI::Application::Compat>, and may also be used for the same purpose by
other template plugins.  This run-time parameter allows you to further
encapsulate instantiating templates, providing potential for more re-usability.
It can be either a scalar or an array reference of multiple paths.

B<REQUEST> - This optional parameter allows you to specify an
already-created CGI::PSGI request object.  Under normal use,
PSGI::Application will instantiate its own CGI::PSGI request object.
Under certain conditions, it might be useful to be able to use
one which has already been created.

B<PARAMS> - This parameter, if used, allows you to set a number
of custom parameters at run-time.  By passing in different
values in different instance scripts which use the same application
module you can achieve a higher level of re-usability.  For instance,
imagine an application module, "Mailform.pm".  The application takes
the contents of a HTML form and emails it to a specified recipient.
You could have multiple instance scripts throughout your site which
all use this "Mailform.pm" module, but which set different recipients
or different forms.

One common use of instance scripts is to provide a path to a config file.  This
design allows you to define project wide configuration objects used by many
several instance scripts. There are several plugins which simplify the syntax
for this and provide lazy loading. Here's an example using
L<CGI::Application::Plugin::ConfigAuto>, which uses L<Config::Auto> to support
many configuration file formats.

 my $app = WebApp->new(PARAMS => { cfg_file => 'config.pl' });

 # Later in your app:
 my %cfg = $self->cfg()
 # or ... $self->cfg('HTML_ROOT_DIR');

See the list of of plugins below for more config file integration solutions.

=head3 run()

The run() method is called you, by L<< psgi_app() >>.  When called, it executes
the functionality in your Application Module.

    my $webapp = WebApp->new();
    $webapp->run();

This method first determines the application state by looking at the
value of the parameter specified by mode_param() (defaults to
'rm' for "Run Mode"), which is expected to contain the name of the mode of
operation.  If not specified, the state defaults to the value
of start_mode().

Once the mode has been determined, run() looks at the dispatch
table stored in run_modes() and finds the function pointer which
is keyed from the mode name.

If found, the function and the framework returns returns the HTTP response data
structure required by the L<PSGI> specification. If the specified mode is not
found in the run_modes() table, run() will croak().

=begin comment

XXX Insert a note about error_mode here(), or about how dispatchers will return 404?
XXX Throw an exception object instead?

=end comment

The structure returned is an arrayref, containing the status code, an arrayref
of header key/values and an arrayref containing the body.

 [ 200, [ 'Content-Type' => 'text/html' ], [ $body ] ]

By default the body is a single scalar, but plugins may modify this to return
other value PSGI values.  See L<PSGI/"The Response"> for details about the
response format.

=head2 Methods to possibly override

PSGI::Application implements some methods which are expected to be overridden
by implementing them in your sub-class module.  These methods are as follows:

=head3 setup()

This method is called by the inherited new() constructor method.  The
setup() method should be used to define the following property/methods:

    mode_param() - set the name of the run mode CGI param.
    start_mode() - text scalar containing the default run mode.
    error_mode() - text scalar containing the error mode.
    run_modes() - hash table containing mode => function mappings.
    tmpl_path() - text scalar or array reference containing path(s) to template files.

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

However, often times all that needs to be in setup() is defining your run modes
and your start mode. L<CGI::Application::Plugin::AutoRunmode> allows you to do
this with a simple syntax, using run mode attributes:

 use CGI::Application::Plugin::AutoRunmode;

 sub show_first : StartRunmode { ... };
 sub do_next : Runmode { ... }

L<< CGI::Application::Plugin::RunmodeDeclare >> further simplifies syntax by using L<Devel::Declare>
and L<Method::Signatures::Simple>:

    package My::PSGIApp;
    use Any::Moose;
    extends 'PSGI::Application::Compat';
    use CGI::Application::Plugin::RunmodeDeclare;

    startmode hello { "Hello!" }

    runmode world($name) {
        return $self->hello
        . ', '
        . $name || "World!";
    }

    errormode oops($c: $exception) {
        return "Something went wrong at "
        . $c->get_current_runmode
        . ". Exception: $exception";
    }

=head3 teardown()

If implemented, this method is called automatically after your application
runs. (but before the web server returns the response! It can be used to clean
up after your operations.  A typical use of the teardown() function is to
disconnect a database connection which was established in the setup() function.
You could also use the teardown() method to store state information about the
application to the server.

=head3 init()

If implemented, this method is called automatically right before the setup()
method is called. The init() method receives, as its parameters, all the
arguments which were sent to the new() method.

An example of the benefits provided by utilizing this hook is creating a custom
"application super-class" from which all your web applications would inherit,
instead of PSGI::Application.

Consider the following:

  # In MySuperclass.pm:
  package MySuperclass;
  extends 'PSGI::Application';
  sub init {
    my $self = shift;
    # Perform some project-specific init behavior
    # such as to load settings from a database or file.
  }


  # In MyApplication.pm:
  package MyApplication;
  extends 'MySuperclass';
  sub setup { ... }
  sub teardown { ... }
  # The rest of your PSGI::Application-based follows...


By using PSGI::Application and the init() method as illustrated,
a suite of applications could be designed to share certain
characteristics.  This has the potential for much cleaner code
built on object-oriented inheritance.


=head3 prerun()

If implemented, this method is called automatically right before the
selected run mode method is called.  This method provides an optional
pre-runmode hook, which permits functionality to be added at the point
right before the run mode method is called.  To further leverage this
hook, the value of the run mode is passed into prerun().

Another benefit provided by utilizing this hook is creating a custom
"application super-class" from which all your web applications would inherit,
instead of PSGI::Application.

Consider the following:

  # In MySuperclass.pm:
  package MySuperclass;
  extends 'PSGI::Application';
  sub prerun {
	my $self = shift;
	# Perform some project-specific init behavior
	# such as to implement run mode specific
	# authorization functions.
  }


  # In MyApplication.pm:
  package MyApplication;
  extends 'MySuperclass';
  sub setup { ... }
  sub teardown { ... }
  # The rest of your PSGI::Application-based follows...


By using PSGI::Application and the prerun() method as illustrated,
a suite of applications could be designed to share certain
characteristics.  This has the potential for much cleaner code
built on object-oriented inheritance.

It is also possible, within your prerun() method, to change the
run mode of your application.  This can be done via the prerun_mode()
method, which is discussed elsewhere in this POD.

=head3 postrun()

If implemented, this hook will be called after the run mode method
has returned its output, but before HTTP headers are generated.  This
will give you an opportunity to modify the body and headers before they
are returned to the web browser.

A typical use for this hook is running the output of an application
through a "filtering" processors.  For example:

  * You want to modify the HTML or HTTP Headers

  * Your run modes return structured data (such as JSON), which you
    want to transform using a standard mechanism.

The postrun() hook receives a reference to the output from
your run mode method, in addition to the application object.  A typical
postrun() method might be implemented as follows:

  sub postrun {
    my $self = shift;
    my $output_ref = shift;

    # Enclose output HTML table ( Normally using templates, not embedded HTML! )
    my $new_output = "<table border=1>";
    $new_output .= "<tr><td> Hello, World! </td></tr>";
    $new_output .= "<tr><td>". $$output_ref ."</td></tr>";
    $new_output .= "</table>";

    # Replace old output with new output
    $$output_ref = $new_output;
  }

With access to the application object you have full access to use all the
methods normally available in a run mode.  You could change the HTTP headers
(via C<header_type()> and C<header_props()> methods) to set up a redirect.  You
could also use the objects properties to apply changes only under certain
circumstance, such as a in only certain run modes, and when a C<param()> is a
particular value.

=head3 get_request()

 my $req = $webapp->get_request;

Override this method to retrieve the request object if you wish to use a
different request interface instead of CGI::PSGI.

The request object is only loaded if it is used on a given request.

If you can use an alternative to CGI::PSGI, it needs to have some compatibility
with the CGI::PSGI API. For simple use, just having a compatible C<param> method
may be sufficient.

If you use the C<path_info> option to the mode_param() method, then we will call
the C<path_info()> method on the request object.


=head2 Essential Application Methods

The following methods are inherited from PSGI::Application, and are available
to be called by your application within your Application Module. They are
called essential because you will use all or most of them to get any
application up and running.  These functions are listed in alphabetical order.

=head3 param()

    $webapp->param('pname' => $somevalue);

The param() method provides a facility through which you may set
application instance properties which are accessible throughout
your application.

The param() method may be used in two basic ways.  First, you may use it
to get or set the value of a parameter:

    $webapp->param('scalar_param' => '123');
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

The new() method provides a shortcut for specifying a number of run-time
parameters at once.  Internally, PSGI::Application calls the param()
method to set these properties.

=head3 req()

    my $req = $webapp->req();
    my $remote_user = $req->remote_user();

This method retrieves the CGI::PSGI request object which has been created
by instantiating your Application Module.  For details on usage of this
request object, refer to L<CGI::PSGI>.
When the new() method is called, a CGI::PSGI object is automatically created.
If, for some reason, you want to use your own CGI::PSGI request object, the new()
method supports passing in your existing request object on construction using
the REQUEST attribute.

There are a few rare situations where you want your own request object to be
used after your Application Module has already been constructed. In that case
you can pass it to C<req()> like this:

    $webapp->req($new_req_object);
    my $req = $webapp->req(); # now uses $new_req_object

=head3 run_modes()

    # The common usage: an arrayref of run mode names that exactly match subroutine names
    $webapp->run_modes([qw/
        form_display
        form_process
    /]);

   # With a hashref, use a different name or a code ref
   $webapp->run_modes(
           'mode1' => 'some_sub_by_name',
           'mode2' => \&some_other_sub_by_ref
    );

This accessor/mutator specifies the dispatch table for the
application states, using the syntax examples above. It returns
the dispatch table as a hash.

The run_modes() method may be called more than once.  Additional values passed
into run_modes() will be added to the run modes table.  In the case that an
existing run mode is re-defined, the new value will override the existing value.
This behavior might be useful for applications which are created via inheritance
from another application, or some advanced application which modifies its
own capabilities based on user input.

The run() method uses the data in this table to send the application to the
correct function as determined by reading the parameter specified by
mode_param() (defaults to 'rm' for "Run Mode").  These functions are referred
to as "run mode methods".

The hash table set by this method is expected to contain the mode
name as a key.  The value should be either a hard reference (a subref)
to the run mode method which you want to be called when the application enters
the specified run mode, or the name of the run mode method to be called:

    'mode_name_by_ref'  => \&mode_function
    'mode_name_by_name' => 'mode_function'

The run mode method specified is expected to return a block of text (e.g.:
HTML) which will eventually be sent back as the body of an HTTP response.  The
run mode method may return its block of text as a scalar or a scalar-ref.

An advantage of specifying your run mode methods by name instead of
by reference is that you can more easily create derivative applications
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

Specifying the run modes by array reference:

    $webapp->run_modes([ 'mode1', 'mode2', 'mode3' ]);

Is is the same as using a hash, with keys equal to values

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
arbitrary code.  PSGI::Application maintains a strict "default-deny" stance
on all method invocation, thereby allowing secure applications
to be built upon it.

B<THE RUN MODE OF LAST RESORT: "AUTOLOAD">

If PSGI::Application is asked to go to a run mode which doesn't exist
it will usually croak() with errors.  If this is not your desired
behavior, it is possible to catch this exception by implementing
a run mode with the reserved name "AUTOLOAD":

  $self->run_modes(
	"AUTOLOAD" => \&catch_my_exception
  );

Before PSGI::Application calls croak() it will check for the existence
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


=head3 start_mode()

    $webapp->start_mode('mode1');

The start_mode contains the name of the mode as specified in the run_modes()
table.  Default mode is "start".  The mode key specified here will be used
whenever the value of the HTML form parameter specified by mode_param() is
not defined.  Generally, this is the first time your application is executed.

=head2 More Application Methods

You can skip this section if you are just getting started.

The following additional methods are inherited from PSGI::Application, and are
available to be called by your application within your Application Module.
These functions are listed in alphabetical order.

=head3 error_mode()

    $webapp->error_mode('my_error_rm');

If the runmode dies for whatever reason, C<run()> will see if you have set a
value for C<error_mode()>. If you have, C<run()> will call that method as a run
mode, passing $@ as the only parameter.

Plugins authors will be interested to know that just before C<error_mode()> is
called, the C<error> hook will be executed, with the error message passed in as
the only parameter.

No C<error_mode> is defined by default.  The death of your C<error_mode()> run
mode is not trapped, so you can also use it to die in your own special way.

For a complete integrated logging solution, check out L<CGI::Application::Plugin::LogDispatch>.

=head3 get_current_runmode()

    $webapp->get_current_runmode();

The C<get_current_runmode()> method will return a text scalar containing
the name of the run mode which is currently being executed.  If the
run mode has not yet been determined, such as during setup(), this method
will return undef.

=head3 header_add()

    # add or replace the 'type' header
    $webapp->header_add( -type => 'image/png' );

    - or -

    # add an additional cookie
    $webapp->header_add(-cookie=>[$extra_cookie]);

The C<header_add()> method is used to add one or more headers to the outgoing
response headers.  The parameters will eventually be passed on to the request object
header() method, so refer to the L<CGI::PSGI> docs for exact usage details.

Unlike calling C<header_props()>, C<header_add()> will preserve any existing
headers. If a scalar value is passed to C<header_add()> it will replace
the existing value for that key.

If an array reference is passed as a value to C<header_add()>, values in
that array ref will be appended to any existing values values for that key.
This is primarily useful for setting an additional cookie after one has already
been set.

=head3 header_props()

    $webapp->header_props(-type=>'image/gif',-expires=>'+3d');

The C<header_props()> method expects a hash of CGI::PSGI-compatible
HTTP header properties.  These properties will be passed directly
to CGI.pm's C<header()> or C<redirect()> methods.  Refer to L<CGI::PSGI>
for exact usage details.

B

Calling header_props any arguments will clobber any existing headers that have
previously set.

C<header_props()> return a hash of all the headers that have currently been
set. It can be called with no arguments just to get the hash current headers
back.

To add additional headers later without clobbering the old ones,
see C<header_add()>.

B<IMPORTANT NOTE REGARDING HTTP HEADERS>

It is through the C<header_props()> and C<header_add()> method that you may modify the outgoing
HTTP headers.  This is necessary when you want to set a cookie, set the mime
type to something other than "text/html", or perform a redirect.  The
header_props() method works in conjunction with the header_type() method.
The value contained in header_type() determines if we use CGI::header() or
CGI::redirect().  The content of header_props() is passed as an argument to
whichever CGI::PSGI method is called.

Understanding this relationship is important if you wish to manipulate
the HTTP header properly.

=head3 header_type()

    $webapp->header_type('redirect');
    $webapp->header_type('none');

This method used to declare that you are setting a redirection header, or that
you want no header to be returned by the framework.  Setting the header to
'none' may be useful if you are streaming content.

The value of 'header' is almost never used, as it is the default.

However, if you want to redirect, just use redirect method documented next.

=head3 redirect()

  return $self->redirect('http://www.example.com/');
  return $self->redirect('http://www.example.com/', '301 Moved Permanently');

Redirect to another URL. A "302" redirect is performed by default. If you wish to set
a different status, you can pass a second argument with the status code.

=head3 forward()

  return $self->forward('rm_name');
  return $self->forward('run_mode_name', @run_mode_params);

Pass control to another run mode and return its output.  This is equivalent to
calling $self->$other_runmode, except that the internal value of the current
run mode is updated. This bookkeeping is important to templating systems and
plugins in some cases.

=cut

# default to looking for a template named after the current run mode
has 'tmpl_filename' => (
    is      => 'rw',
    isa     => 'Str',
    builder => 'build_tmpl_filename',
    lazy    => 1,
    init_arg => undef,
);
sub build_tmpl_filename { shift->get_current_runmode . '.html' }
=pod

=head3 mode_param()

 # Name the HTML form parameter that contains the run mode name.
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

Here, a HTML form parameter is named that will contain the name of the run mode
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
first "/"). To specify that you would rather get the run mode name from the 2nd
part of $ENV{PATH_INFO}:

 $webapp->mode_param( path_info=> 2 );

This also demonstrates that you don't need to pass in the C<param> hash key. It will
still default to C<rm>.

You can also set C<path_info> to a negative value. This works just like a negative
list index: if it is -1 the run mode name will be taken from the last part of
$ENV{PATH_INFO}, if it is -2, the one before that, and so on.


If no run mode is found in $ENV{PATH_INFO}, it will fall back to looking in the
value of a the HTML form field defined with 'param', as described above.  This
allows you to use the convenient $ENV{PATH_INFO} trick most of the time, but
also supports the edge cases, such as when you don't know what the run mode
will be ahead of time and want to define it with JavaScript.

B<More about $ENV{PATH_INFO}>.

Using $ENV{PATH_INFO} to name your run mode creates a clean separation between
the form variables you submit and how you determine the processing run mode. It
also creates URLs that are more search engine friendly. Let's look at an
example form submission using this syntax:

	<form action="/instance.psgi/edit_form" method=post>
		<input type="hidden" name="breed_id" value="4">

Here the run mode would be set to "edit_form". Here's another example with a
req string:

	-/instance.psgi/edit_form?breed_id=2

This demonstrates that you can use $ENV{PATH_INFO} and a req string together
without problems. $ENV{PATH_INFO} is defined as part of the CGI specification
should be supported by any web server that supports CGI scripts.

=cut

sub mode_param {
	my $self = shift;
	my $mode_param;

	my %p;
	# expecting a scalar or code ref
	if ((scalar @_) == 1) {
		$mode_param = $_[0];
	}
	# expecting hash style params
	else {
		croak("PSGI::Application->mode_param() : You gave me an odd number of parameters to mode_param()!")
		unless ((@_ % 2) == 0);
		%p = @_;
		$mode_param = $p{param};

		if ( $p{path_info} && $self->req->path_info() ) {
			my $pi = $self->req->path_info();

			my $idx = $p{path_info};
			# two cases: negative or positive index
			# negative index counts from the end of path_info
			# positive index needs to be fixed because
			#    computer scientists like to start counting from zero.
			$idx -= 1 if ($idx > 0) ;

			# remove the leading slash
			$pi =~ s!^/!!;

			# grab the requested field location
			$pi = (split q'/', $pi)[$idx] || '';

			$mode_param = (length $pi) ?  { run_mode => $pi } : $mode_param;
		}

	}

	# If data is provided, set it
	if (defined $mode_param and length $mode_param) {
        $self->_mode_param($mode_param);
	}

	return $self->_mode_param;
}


=head3 prerun_mode()

    $webapp->prerun_mode('new_run_mode');

The prerun_mode() method is an accessor/mutator which can be used within
your prerun() method to change the run mode which is about to be executed.
For example, consider:

  # In WebApp.pm:
  package WebApp;
  extends 'PSGI::Application';
  sub prerun {
	my $self = shift;

	# Get the web user name, if any
	my $req = $self->req();
	my $user = $req->remote_user();

	# Redirect to login, if necessary
	unless ($user) {
		$self->prerun_mode('login');
	}
  }


In this example, the web user will be forced into the "login" run mode
unless they have already logged in.  The prerun_mode() method permits
a scalar text string to be set which overrides whatever the run mode
would otherwise be.

The use of prerun_mode() within prerun() differs from setting
mode_param() to use a call-back via subroutine reference.  It differs
because prerun() allows you to selectively set the run mode based
on some logic in your prerun() method.  The call-back facility of
mode_param() forces you to entirely replace PSGI::Application's mechanism
for determining the run mode with your own method.  The prerun_mode()
method should be used in cases where you want to use PSGI::Application's
normal run mode switching facility, but you want to make selective
changes to the mode under specific conditions.

B<Note:>  The prerun_mode() method may ONLY be called in the context of
a prerun() method.  Your application will die() if you call
prerun_mode() elsewhere, such as in setup() or a run mode method.

=head2 Dispatching Clean URIs to run modes

Modern web frameworks dispense with cruft in URIs, providing in clean
URIs instead. Instead of:

 /item.psgi?rm=view&id=15

A clean URI to describe the same resource might be:

 /item/15/view

The process of mapping these URIs to run modes is called dispatching and is
handled by L<CGI::Application::Dispatch::PSGI>. Dispatching is not required and is a
layer you can fairly easily add to an application later.

=head2 Offline website development

You can work on your PSGI::Application project on your desktop or laptop
with a Perl-based web server if you'd like. L<< HTTP::Server::PSGI >> is  
the simplest option, but there are several more PSGI Perl web servers including
L<< Starman >> and L<< Starlet >>.

=head2 Automated Testing

There are some testing modules specifically made for PSGI applications.

L<Plack::Test> is one option. You can also use L<Test::WWW::Mechanize> to test
the app through any web server.

=head1 PLUG-INS

PSGI::Application has a plug-in architecture that is easy to use and easy
to develop new plug-ins for.

Keep in mind that many of the Plack "Middleware" framework extensions will also
work with PSGI::Application, and some Moose Roles modules may be usable as well.

=head2 Recommended Plug-ins

The following plugins are recommended for general purpose web/db development:

=over 4

=item *

L<CGI::Application::Plugin::ConfigAuto> - Keeping your config details in a separate file is recommended for every project. This one integrates with L<Config::Auto>. Several more config plugin options are listed below.

=item *

L<CGI::Application::Plugin::DBH> - Provides easy management of one or more database handles and can delay making the database connection until the moment it is actually used.

=item *

L<CGI::Application::Plugin::FillInForm> - makes it a breeze to fill in an HTML form from data originating from a CGI req or a database record.

=item *

L<CGI::Application::Plugin::Session> - For a project that requires session
management, this plugin provides a useful wrapper around L<CGI::Session>

=item *

L<CGI::Application::Plugin::ValidateRM> - Integration with Data::FormValidator and HTML::FillInForm

=back

=head2 More plug-ins

Many more plugins are available as alternatives and for specific uses.

This list is far from complete. For a current complete list, please consult CPAN:

L<Search for PSGI::Application::Plugin*|http://search.cpan.org/search?m=dist&q=PSGI%2DApplication%2DPlugin>

L<Search for CGI::Application::Plugin*|http://search.cpan.org/search?m=dist&q=CGI%2DApplication%2DPlugin>

=over 4

=item *

L<CGI::Application::Plugin::AnyTemplate> - Use several different templating system from within PSGI::Application using a unified interface

=item *

L<CGI::Application::Plugin::AutoRunmode> - Automatically register runmodes


=item *

L<CGI::Application::Plugin::Config::Context> - Integration with L<Config::Context>.

=item *

L<CGI::Application::Plugin::Config::General> - Integration with L<Config::General>.

=item *

L<CGI::Application::Plugin::Config::Simple> - Integration with L<Config::Simple>.

=item *

L<CGI::Application::Plugin::LogDispatch> - Integration with L<Log::Dispatch>

=item *

L<CGI::Application::Plugin::Stream> - Help stream files to the browser

=item *

L<CGI::Application::Plugin::TT> - Use L<Template::Toolkit> as an alternative to HTML::Template.


=back

Consult each plug-in for the exact usage syntax.

=head2 Writing Plug-ins

Before you consider writing a plugin specific to this framework, consider if
you provide the functionality you need through a PSGI "Middleware" or by using
a Moose role. These methods may produce solutions that are more flexible and
re-usable.

In come cases, you may need some framework-specific functionality, so writing 
something specific to PSGI::Application would the best option.

Writing plug-ins is simple. Simply create a new role with C<Any::Moose>:

 package PSGI::Application::Plugin::MyPlugin;
 use Any::Moose 'Role';

Follow the L<Moose Roles|Moose::Manual::Roles> documentation on creating a new role
that adds methods to the application object.

If you want to write a plugin that's also compatible with both
PSGI::Application and CGI::Application, you could refer to the plug-in docs
for CGI::Application.

=head2 Writing Advanced Plug-ins - Using callbacks

When writing a plug-in, you may want some action to happen automatically at a
particular stage, such as setting up a database connection or initializing a
session. By using these 'callback' methods, you can register a subroutine
to run at a particular phase, accomplishing this goal.

B<Callback Examples>

  # register a callback to the standard PSGI::Application hooks
  #   one of 'init', 'prerun', 'postrun', 'teardown' or 'load_tmpl'
  # As a plug-in author, this is probably the only method you need.

  # Class-based: callback will persist for all runs of the application
  $class->add_callback('init', \&some_other_method);

  # Object-based: callback will only last for lifetime of this object
  $self->add_callback('prerun', \&some_method);

  # If you want to create a new hook location in your application,
  # You'll need to know about the following two methods to create
  # the hook and call it.

  # Create a new hook
  $self->new_hook('pretemplate');

  # Then later execute all the callbacks registered at this hook
  $self->call_hook('pretemplate');

B<Callback Methods>

=head3 add_callback()

	$self->add_callback ('teardown', \&callback);
	$class->add_callback('teardown', 'method');

The add_callback method allows you to register a callback
function that is to be called at the given stage of execution.
Valid hooks include 'init', 'prerun', 'postrun' and 'teardown',
'load_tmpl', and any other hooks defined using the C<new_hook>
method.

The callback should be a reference to a subroutine or the name of a
method.

If multiple callbacks are added to the same hook, they will all be
executed one after the other.  The exact order depends on which class
installed each callback, as described below under B<Callback Ordering>.

Callbacks can either be I<object-based> or I<class-based>, depending
upon whether you call C<add_callback> as an object method or a class
method:

	# add object-based callback
	$self->add_callback('teardown', \&callback);

	# add class-based callbacks
	$class->add_callback('teardown', \&callback);
	My::Project->add_callback('teardown', \&callback);

Object-based callbacks are stored in your web application's C<$c>
object; at the end of the request when the C<$c> object goes out of
scope, the callbacks are gone too.

Object-based callbacks are useful for one-time tasks that apply only to
the current running application.  For instance you could install a
C<teardown> callback to trigger a long-running process to execute at the
end of the current request, after all the HTML has been sent to the
browser.

Class-based callbacks survive for the duration of the running Perl process.
(In a persistent environment such as C<mod_perl> a single Perl process can
serve many web requests.)

Class-based callbacks are useful for plugins to add features to all web
applications.

Another feature of class-based callbacks is that your plugin can create
hooks and add callbacks at any time - even before the web application's
C<$self> object has been initialized.  A good place to do this is in
your plugin's C<import> subroutine:

	package PSGI::Application::Plugin::MyPlugin;
	use parent 'Exporter';
	sub import {
		my $caller = scalar(caller);
		$caller->add_callback('init', 'my_setup');
		goto &Exporter::import;
	}

Notice that C<< $caller->add_callback >> installs the callback
on behalf of the module that contained the line:

	use PSGI::Application::Plugin::MyPlugin;

=cut

has '_instance_callbacks' => (
    is          => 'rw',
    isa         => 'HashRef',
    default     => sub { +{} },
);


sub add_callback {
	my ($self_or_class, $hook, $callback) = @_;

	$hook = lc $hook;

	confess "no callback provided when calling add_callback" unless $callback;
	confess "Unknown hook ($hook)"                           unless exists $CLASS_CALLBACKS{$hook};

	if (ref $self_or_class) {
		# Install in object
        my $self = $self_or_class;
        $self->_instance_callbacks()->{$hook} = []
            unless $self->_instance_callbacks()->{$hook};
        push @{ $self->_instance_callbacks()->{$hook} }, $callback;
	}
	else {
		# Install in class
		my $class = $self_or_class;
		push @{ $CLASS_CALLBACKS{$hook}{$class} }, $callback;
	}

}

=head3 new_hook(HOOK)

    $self->new_hook('pretemplate');

The C<new_hook()> method can be used to create a new location for developers to
register callbacks.  It takes one argument, a hook name. The hook location is
created if it does not already exist. A true value is always returned.

For an example, L<CGI::Application::Plugin::TT> adds hooks before and after every
template is processed.

See C<call_hook(HOOK)> for more details about how hooks are called.

=cut

sub new_hook {
	my ($class, $hook) = @_;
	$CLASS_CALLBACKS{$hook} ||= {};
	return 1;
}

=head3 call_hook(HOOK)

    $self->call_hook('pretemplate', @args);

The C<call_hook> method is used to executed the callbacks that have been registered
at the given hook.  It is used in conjunction with the C<new_hook> method which
allows you to create a new hook location.

The first argument to C<call_hook> is the hook name. Any remaining arguments
are passed to every callback executed at the hook location. So, a stub for a
callback at the 'pretemplate' hook would look like this:

 sub my_hook {
    my ($self,@args) = @_;
    # ....
 }

Note that hooks are semi-public locations. Calling a hook means executing
callbacks that were registered to that hook by the current object and also
those registered by any of the current object's parent classes.  See below for
the exact ordering.

=cut

# cache item to remember callback classes checked so we don't have to do the
# expensive $app_class->meta->linearized_isa every time
has '_superclass_cache' => (
    is          => 'ro',
    isa         => 'ArrayRef[Str]',
    default     => sub {
        my $self = shift;
	    my $app_class = ref $self || $self;
        return [ $app_class->meta->linearized_isa ];
    },
    lazy        => 1,
    init_arg    => undef,
    auto_deref  => 1,
);

has '_instance_callbacks' => (
    is          => 'rw',
    isa         => 'HashRef',
    default     => sub { +{} },
    init_arg    => undef,
);

sub call_hook {
	my $self      = shift;
	my $app_class = ref $self || $self;
	my $hook      = lc shift;
	my @args      = @_;

	confess "Unknown hook ($hook)" unless exists $CLASS_CALLBACKS{$hook};

	my %executed_callback;

	# First, run callbacks installed in the object
    my @instance_callbacks =  defined $self->_instance_callbacks()->{$hook}
                           ? @{ $self->_instance_callbacks()->{$hook} }
                           : ()
                           ;
    for my $callback ( @instance_callbacks ) {
        next if $executed_callback{$callback};
        try   { $self->$callback(@args); }
        catch { confess "Error executing object callback in $hook stage: $_" };
        $executed_callback{$callback} = 1;
    }

	# Next, run callbacks installed in class hierarchy

	# Get list of classes that the current app inherits from
	for my $class ($self->_superclass_cache) {

		# skip those classes that contain no callbacks
		next unless exists $CLASS_CALLBACKS{$hook}{$class};

		# call all of the callbacks in the class
		for my $callback (@{ $CLASS_CALLBACKS{$hook}{$class} }) {
			next if $executed_callback{$callback};
			try { $self->$callback(@args); };
            catch { die "Error executing class callback in $hook stage: $_"; };
			$executed_callback{$callback} = 1;
		}
	}

}

__PACKAGE__->meta->make_immutable(); 1;

__END__

=pod

B<Callback Ordering>

Object-based callbacks are run before class-based callbacks.

The order of class-based callbacks is determined by the inheritance tree of the
running application. The built-in methods of C<init>, C<prerun>,
C<postrun>, and C<teardown> are also executed this way, according to the
ordering below.

In a persistent environment, there might be a lot of applications
in memory at the same time.  For instance:

	PSGI::Application
	  Other::Project   # uses CGI::Application::Plugin::Baz
		 Other::App    # uses CGI::Application::Plugin::Bam

	  My::Project      # uses CGI::Application::Plugin::Foo
		 My::App       # uses CGI::Application::Plugin::Bar

Suppose that each of the above plugins each added a callback to be run
at the 'init' stage:

	Plugin                           init callback
	------                           -------------
	CGI::Application::Plugin::Baz    baz_startup
	CGI::Application::Plugin::Bam    bam_startup

	CGI::Application::Plugin::Foo    foo_startup
	CGI::Application::Plugin::Bar    bar_startup

When C<My::App> runs, only C<foo_callback> and C<bar_callback> will
run.  The other callbacks are skipped.

The C<@ISA> list of C<My::App> is:

	My::App
	My::Project
	PSGI::Application

This order determines the order of callbacks run.

When C<call_hook('init')> is run on a C<My::App> application, callbacks
installed by these modules are run in order, resulting in:
C<bar_startup>, C<foo_startup>, and then finally C<init>.

If a single class installs more than one callback at the same hook, then
these callbacks are run in the order they were registered (FIFO).



=cut

=head1 COMPATIBILITY WITH CGI::Application

PSGI::Application features a number of differences with CGI::Application.
However, to make it easier to use CGI::Application projects and plugins
with PSGI::Application, we provide L<PSGI::Application::Compat>, which
allows most CGI::Application code and plugins to be used without modifications.

Here's the list of of differences with CGI::Application.

=head2 Official API Changes

=over 4

=item * B<< Removed dump() and dump_html >>

This functionality is now provided through
L<CGI::Application::Plugin::DevPopup>.  This means the request object is no
longer expected to have the Dump() and escapeHTML() methods.

=item * B<< run_as_psgi() is now just run() >>

The non-PSGI code path has been removed. This simplifies the interface and
documentation, while still giving you the flexibility to run in all the
environments that were previously supported.

=item * B<< The cgiapp_ prefix is dropped from method names >>

The following method names had the cgiapp_ prefix dropped: cgiapp_init, cgiapp_prerun, cgiapp_postrun.
Also, cgiapp_get_query is now "get_request()".

=item * B<< C<<query()>> is now C<<req()>> and C<< new(QUERY=>...) >> is now C<< new(REQUEST=>...) >> >>

This object is primarily used to model an HTTP request.  C<< req() >> is a
common method name for this in other frameworks, providing a measure of compatibility.

=item * B<< Hash keys for new() must now be upper-case now. >>

They are case-insensitive previously. That "feature" was rarely exercised, but
created extra busy-work for plugin authors to be consistent.

=item * B<< The delete() method has been removed. >>

This rarely-used method removed params that had been set in the object.
Removing this method removes state options from the object, reducing some kinds
of bugs.  If you need a read-write data structure based on the initial C<< param() >>
settings, consider making a copy.

=item * B<< The default request object has changed from CGI.pm to CGI::PSGI >>

In practice, this should work practically the same. The default request object
may change again in the future to something is more PSGI native, generally
CGI.pm compatible, but lacks the HTML-generation code from CGI.pm. In any case,
overriding the default can be done in one line of code.

=item * B<< The default 'start_mode' behavior has changed. >>

It now returns a "Hello World" message instead of dumping out debugging information. This
is usually immediately redefined during development and should not be noticeable accept
as a first impression.

A new method is available called "default_run_modes" for plugins or sub-classes
that want to provide an alternate default run mode. For example, a debugging
plugin that prints diagnostic information, or a framework based on this which
wants to provide a pretty branded page for an enhanced first impression. It
won't be used in normal development.

For typical use, these changes have no impact.

=item * B<< forward() and redirect() are now in the core. >>

These are the same methods previously provided by L<CGI::Application::Plugin::Forward>
and L<CGI::Application::Plugin::Redirect>. These common functions are available without
extra syntax of loading plugins to use them.

=item * B<< load_tmpl() and html_tmpl_class() have been removed >>

PSGI::Application has moved templating support out of the core for now. A
future release of PSGI::Application will provide or endorse an official
templating API, while L<PSGI::Application::Compat> will continue to provide
the removed methods.  L<CGI::Application::Plugin::TT> provides excellent
support for Template Toolkit.

=back

=head2 Internal API changes

The section should ideally only be of interest to plugin authors, who may have
accessed some of the internal API directly.

The internal changes can be summed up by saying that we switched to using Any::Moose
internally, so there is no more direct access into the internal object structure
in the code-- everything happens through method calls. So generally, if you
were accessing an attribute named C<< $self->{__FOO} >>  before, it's now
accessible through C<<$self->_foo>>. A quick search in the source code
should find what you need. Some other notable internal changes include:

=over 4

=item * B<< _cap_hash() was removed. >>

It shouldn't be needed any more, due to a policy change to just do
case-sensitive matching.

=item * B<< $INSTALLED_CALLBACKS is now known as $CLASS_CALLBACKS >>

Previously we were using two variables named "INSTALLED_CALLBACKS" to hold both
class-based callbacks and instance-based callbacks. The distinction between the
two variables has now been further clarified.

=back




