
use	strict;
use Test::More;
use CGI::PSGI;
use PSGI::Application;

# Record the subroutines we've seen in a session
my @Event_History;

sub	main::record_event {
	my ($hook_name)	= @_;

	my $sub		= (caller 1)[3];

	push @Event_History, "$hook_name/$sub";
}




######################################
{
	package	PSGI::Application::Plugin::Foo;
	use	vars qw/@EXPORT	@ISA/;
	@ISA	   = ('Exporter');
	@EXPORT	   = qw(
		foo_custom
		foo_init1
		foo_init2
		foo_prerun
		foo_postrun
		foo_teardown
	);

	sub	import {
		my $caller = caller;
		$caller->new_hook('foo_hook');

		# Foo's hooks are added by reference.  They cannot be overridden by the
		# application

		$caller->add_callback('foo_hook', \&foo_custom);
		$caller->add_callback('init',     \&foo_init1);
		$caller->add_callback('init',     \&foo_init2);
		$caller->add_callback('prerun',   \&foo_prerun);
		$caller->add_callback('postrun',  \&foo_postrun);
		$caller->add_callback('teardown', \&foo_teardown);
		goto &Exporter::import;
	}
	sub	foo_custom	 { main::record_event('foo_hook') }
	sub	foo_init1	 { main::record_event('init')     }
	sub	foo_init2	 { main::record_event('init')     }
	sub	foo_prerun	 { main::record_event('prerun')   }
	sub	foo_postrun	 { main::record_event('postrun')  }
	sub	foo_teardown {
		my $self = shift;
		main::record_event('teardown');
		$self->call_hook('foo_hook');
	}

}
######################################
{
	package	PSGI::Application::Plugin::Bar;
	use	vars qw/@EXPORT	@ISA/;
	@ISA	   = ('Exporter');
	@EXPORT	   = qw(
		bar_custom
		bar_init1
		bar_init2
		bar_prerun
		bar_postrun
		bar_teardown
	);


	sub	import {
		my $caller = caller;
		$caller->new_hook('bar_hook');
		$caller->add_callback('bar_hook', 'bar_custom');
		$caller->add_callback('init',     'bar_init1');
		$caller->add_callback('init',     'bar_init2');
		$caller->add_callback('prerun',   'bar_prerun');
		$caller->add_callback('postrun',  'bar_postrun');
		$caller->add_callback('teardown', 'bar_teardown');
		goto &Exporter::import;
	}
	sub	bar_custom	 { main::record_event('bar_hook')    }
	sub	bar_init1	 {
		my $self = shift;
		main::record_event('init');
		$self->call_hook('bar_hook');
	}
	sub	bar_init2	 { main::record_event('init')     }
	sub	bar_prerun	 { main::record_event('prerun')   }
	sub	bar_postrun	 { main::record_event('postrun')  }
	sub	bar_teardown { main::record_event('teardown') }

}
######################################
{
	package	PSGI::Application::Plugin::Baz;
	use	vars qw/@EXPORT	@ISA/;
	@ISA	   = ('Exporter');
	@EXPORT	   = qw(
		baz_custom
		baz_init1
		baz_init2
		baz_prerun
		baz_postrun
		baz_teardown
	);

	sub	import {
		my $caller = caller;
		$caller->new_hook('baz_hook');
		$caller->add_callback('baz_hook', 'baz_custom');
		$caller->add_callback('init',     'baz_init1');
		$caller->add_callback('init',     'baz_init2');
		$caller->add_callback('prerun',   'baz_prerun');
		$caller->add_callback('postrun',  'baz_postrun');
		$caller->add_callback('teardown', 'baz_teardown');
		goto &Exporter::import;
	}
	sub	baz_custom	 { main::record_event('baz_hook')  }
	sub	baz_init1	 { main::record_event('init')      }
	sub	baz_init2	 { main::record_event('init')      }
	sub	baz_prerun	 {
		my $self = shift;
		main::record_event('prerun');
		$self->call_hook('baz_hook');
	}
	sub	baz_postrun	 { main::record_event('postrun')   }
	sub	baz_teardown { main::record_event('teardown')  }

}
######################################
{
	package	PSGI::Application::Plugin::Bam;
	use	vars qw/@EXPORT	@ISA/;
	@ISA	   = ('Exporter');
	@EXPORT	   = qw(
		bam_custom
		bam_init1
		bam_init2
		bam_prerun
		bam_postrun
		bam_teardown
	);


	sub	import {
		my $caller = caller;
		$caller->new_hook('bam_hook');
		$caller->add_callback('bam_hook', 'bam_custom');
		$caller->add_callback('init',     'bam_init1');
		$caller->add_callback('init',     'bam_init2');
		$caller->add_callback('prerun',   'bam_prerun');
		$caller->add_callback('postrun',  'bam_postrun');
		$caller->add_callback('teardown', 'bam_teardown');
		goto &Exporter::import;
	}

	sub	bam_custom	 { main::record_event('bam_hook') }
	sub	bam_init1	 { main::record_event('init')     }
	sub	bam_init2	 { main::record_event('init')     }
	sub	bam_prerun	 { main::record_event('prerun')   }
	sub	bam_postrun	 {
		my $self = shift;
		main::record_event('postrun');
		$self->call_hook('bam_hook');
	}
	sub	bam_teardown { main::record_event('teardown')  }

}

######################################
{
	package	My::Framework;
    use Any::Moose;
    extends 'PSGI::Application';
	sub	init	  { main::record_event('init')       }
	sub	prerun    { main::record_event('prerun')     }
	sub	postrun   { main::record_event('postrun')    }
	sub	teardown  { main::record_event('teardown')   }
}

######################################
{
	package	My::Project;
    use Any::Moose;
    extends 'PSGI::Application'; 
	import PSGI::Application::Plugin::Foo;

	# install another init callback	for	all	users of My::Project
	My::Project->add_callback('init',      'my_project_init');

	# install an impolite callback that	will get run by	all	PSGI::Application apps
	# regardless of	whether	or not they	use	My::Project
	PSGI::Application->add_callback('init', \&my_project_global_init);

	sub	my_project_init	{ main::record_event('init')          }
	sub	my_project_global_init { main::record_event('init')   }

}

######################################
{
	package	Other::Project;
    use Any::Moose;
    extends 'My::Framework';
	import PSGI::Application::Plugin::Baz;
	import PSGI::Application::Plugin::Bam;

	# install another init callback	for	all	users of Other::Project
	Other::Project->add_callback('init',      'other_project_init');

	# install an impolite callback that	will get run by	all	PSGI::Application apps
	# regardless of	whether	or not they	use	My::Project
	PSGI::Application->add_callback('init', \&other_project_global_init);

	sub	other_project_init { main::record_event('init')          }
	sub	other_project_global_init {	main::record_event('init')   }

}

######################################
{
	package	My::App;
    use Any::Moose;
    extends 'My::Project';
	import PSGI::Application::Plugin::Bar;

	sub	setup {
		my $self = shift;
		$self->header_type('none');
		$self->run_modes(['begin']);
		$self->start_mode('begin');
	}
	sub	init		{
		my $self = shift;
		main::record_event('init');
		__PACKAGE__->add_callback('prerun', 'my_app_class_prerun');
		__PACKAGE__->add_callback('teardown', 'my_app_teardown');
		$self->add_callback('teardown', 'my_app_teardown');
	}
	sub	prerun		        { main::record_event('prerun')      }
	sub	my_app_class_prerun	{ main::record_event('prerun')      }
	sub	my_app_obj_prerun	{ main::record_event('prerun')      }
	sub	my_app_teardown		{ main::record_event('teardown')    }
	sub	postrun		        { main::record_event('postrun')     }
	sub	teardown			{ main::record_event('teardown')    }

	sub	begin {
		main::record_event('runmode');
		return '';
	}

}

######################################
{
	package	Other::App;
    use Any::Moose;
    extends 'Other::Project';
	import PSGI::Application::Plugin::Bam;

	sub	setup {
		my $self = shift;
		$self->header_type('none');
		$self->run_modes(['begin']);
		$self->start_mode('begin');
	}
	sub	init		{
		my $self = shift;
		$self->add_callback('postrun', 'other_app_postrun');
		main::record_event('init')
	}
	sub	prerun	   { main::record_event('prerun')      }
	sub	postrun	   { main::record_event('postrun')     }
	sub	other_app_postrun  { main::record_event('postrun')     }
	sub	teardown		   { main::record_event('teardown')    }

	sub	begin {
		main::record_event('runmode');
		return '';
	}
}

{
	package	Unrelated::App;
    use Any::Moose;
    extends 'PSGI::Application';

	sub	setup {
		my $self = shift;
		$self->header_type('none');
		$self->run_modes(['begin']);
		$self->start_mode('begin');
	}
	sub	init	   { main::record_event('init')        }
	sub	prerun	   { main::record_event('prerun')      }
	sub	postrun	   { main::record_event('postrun')     }
	sub	teardown   { main::record_event('teardown')    }

	sub	begin {
		main::record_event('runmode');
		return '';
	}
}


@Event_History = ();

my $app	= My::App->new( REQUEST => CGI::PSGI->new({}) );
$app->add_callback('prerun', 'my_app_obj_prerun');
$app->run;

my @expected_events	= (
	# init

	'init/PSGI::Application::Plugin::Bar::bar_init1',        # CAP::Bar
	'bar_hook/PSGI::Application::Plugin::Bar::bar_custom',
	'init/PSGI::Application::Plugin::Bar::bar_init2',

	'init/PSGI::Application::Plugin::Foo::foo_init1',        # CAP::Foo
	'init/PSGI::Application::Plugin::Foo::foo_init2',


	'init/My::Project::my_project_init',                   # My::Project

	'init/My::App::init',                           # My::App (but installed via PSGI::Application)

	'init/My::Project::my_project_global_init',            # My::Project (rudely) registered a callback in the
														   # PSGI::Application class

	'init/Other::Project::other_project_global_init',      # Other::Project (rudely) registered a callback in the
														   # PSGI::Application class, which forces us to	run	it


	# prerun

	'prerun/My::App::my_app_obj_prerun',                   # My::App (installed in object)

	'prerun/PSGI::Application::Plugin::Bar::bar_prerun',    # CAP::Foo

	'prerun/My::App::my_app_class_prerun',                 # My::App (but installed at runtime)

	'prerun/PSGI::Application::Plugin::Foo::foo_prerun',    # CAP::Bar

	'prerun/My::App::prerun',                       # My::App (but installed via PSGI::Application)


	# Run mode
	'runmode/My::App::begin',                              # My::App

	# postrun
	'postrun/PSGI::Application::Plugin::Bar::bar_postrun',  # CAP::Bar
	'postrun/PSGI::Application::Plugin::Foo::foo_postrun',  # CAP::Foo
	'postrun/My::App::postrun',                     # My::App (but installed via PSGI::Application)

	# teardown
	'teardown/My::App::my_app_teardown',                   # My::App (but installed in object)

	'teardown/PSGI::Application::Plugin::Bar::bar_teardown',  # CAP::Bar
	'teardown/PSGI::Application::Plugin::Foo::foo_teardown',  # CAP::Foo
	'foo_hook/PSGI::Application::Plugin::Foo::foo_custom',    # CAP::Foo
	'teardown/My::App::teardown',                            # My::App (but installed via PSGI::Application)

);


is_deeply(\@Event_History, \@expected_events, 'My::App - callbacks executed correctly (first run)')
   or do {
		use	Data::Dumper;
		print STDERR "Actual Event History: \n";
		print STDERR Dumper	\@Event_History;
};

# Second run of	My::App	: the callback registered directly in self are
# no longer	installed

@Event_History = ();

My::App->psgi_app->();

@expected_events = (
	# init

	'init/PSGI::Application::Plugin::Bar::bar_init1',        # CAP::Bar
	'bar_hook/PSGI::Application::Plugin::Bar::bar_custom',
	'init/PSGI::Application::Plugin::Bar::bar_init2',

	'init/PSGI::Application::Plugin::Foo::foo_init1',        # CAP::Foo
	'init/PSGI::Application::Plugin::Foo::foo_init2',


	'init/My::Project::my_project_init',                   # My::Project

	'init/My::App::init',                           # My::App (but installed via PSGI::Application)

	'init/My::Project::my_project_global_init',            # My::Project (rudely) registered a callback in the
														   # PSGI::Application class

	'init/Other::Project::other_project_global_init',      # Other::Project (rudely) registered a callback in the
														   # PSGI::Application class, which forces us to	run	it


	# prerun


	'prerun/PSGI::Application::Plugin::Bar::bar_prerun',    # CAP::Foo

	'prerun/My::App::my_app_class_prerun',                 # My::App (but installed at runtime)


	'prerun/PSGI::Application::Plugin::Foo::foo_prerun',    # CAP::Bar

	'prerun/My::App::prerun',                       # My::App (but installed via PSGI::Application)


	# Run mode
	'runmode/My::App::begin',                              # My::App

	# postrun
	'postrun/PSGI::Application::Plugin::Bar::bar_postrun',  # CAP::Bar
	'postrun/PSGI::Application::Plugin::Foo::foo_postrun',  # CAP::Foo
	'postrun/My::App::postrun',                     # My::App (but installed via PSGI::Application)

	# teardown
	'teardown/My::App::my_app_teardown',                   # My::App (but installed in object)

	'teardown/PSGI::Application::Plugin::Bar::bar_teardown',  # CAP::Bar
	'teardown/PSGI::Application::Plugin::Foo::foo_teardown',  # CAP::Foo
	'foo_hook/PSGI::Application::Plugin::Foo::foo_custom',    # CAP::Foo
	'teardown/My::App::teardown',                            # My::App (but installed via PSGI::Application)

);


is_deeply(\@Event_History, \@expected_events, 'My::App - callbacks executed correctly (second run)')
   or do {
		use	Data::Dumper;
		print STDERR "Actual Event History: \n";
		print STDERR Dumper	\@Event_History;
};











@Event_History = ();
Other::App->psgi_app->();

@expected_events = (
	# init

	'init/PSGI::Application::Plugin::Bam::bam_init1',        # CAP::Bam
	'init/PSGI::Application::Plugin::Bam::bam_init2',

	'init/PSGI::Application::Plugin::Baz::baz_init1',        # CAP::Baz
	'init/PSGI::Application::Plugin::Baz::baz_init2',


	'init/Other::Project::other_project_init',             # Other::Project

	'init/Other::App::init',                        # Other::App (but installed via PSGI::Application)

	'init/My::Project::my_project_global_init',            # My::Project (rudely) registered a callback in the
														   # PSGI::Application class, which forces us to	run	it

	'init/Other::Project::other_project_global_init',      # Other::Project (rudely) registered a callback in the
														   # PSGI::Application class


	# prerun


	'prerun/PSGI::Application::Plugin::Bam::bam_prerun',    # CAP::Baz

	'prerun/PSGI::Application::Plugin::Baz::baz_prerun',    # CAP::Bam

	'baz_hook/PSGI::Application::Plugin::Baz::baz_custom',  # CAP::Bam


	'prerun/Other::App::prerun',                    # Other::App (but installed via PSGI::Application)


	# Run mode
	'runmode/Other::App::begin',                           # Other::App

	# postrun
	'postrun/Other::App::other_app_postrun',               # Other::App (but installed in object)

	'postrun/PSGI::Application::Plugin::Bam::bam_postrun',  # CAP::Bam
	'bam_hook/PSGI::Application::Plugin::Bam::bam_custom',  # CAP::Bam


	'postrun/PSGI::Application::Plugin::Baz::baz_postrun',  # CAP::Baz
	'postrun/Other::App::postrun',                  # Other::App (but installed via PSGI::Application)

	# teardown
	'teardown/PSGI::Application::Plugin::Bam::bam_teardown',  # CAP::Bam
	'teardown/PSGI::Application::Plugin::Baz::baz_teardown',  # CAP::Baz
	'teardown/Other::App::teardown',                         # Other::App (but installed via PSGI::Application)

);

is_deeply(\@Event_History, \@expected_events, 'Other::App - callbacks executed correctly')
   or do {
		use	Data::Dumper;
		print STDERR "Actual Event History: \n";
		print STDERR Dumper	\@Event_History;
};


@Event_History = ();
Unrelated::App->psgi_app->();

@expected_events = (
	# init

	'init/Unrelated::App::init',                    # Unrelated::App (but installed via PSGI::Application)

	'init/My::Project::my_project_global_init',            # My::Project (rudely) registered a callback in the
														   # PSGI::Application class, which forces us to	run	it

	'init/Other::Project::other_project_global_init',      # Unrelated::Project (rudely) registered a callback in the
														   # PSGI::Application class, which forces us to	run	it


	# prerun

	'prerun/Unrelated::App::prerun',                # Unrelated::App (but installed via PSGI::Application)


	# Run mode
	'runmode/Unrelated::App::begin',                       # Unrelated::App

	# postrun
	'postrun/Unrelated::App::postrun',              # Unrelated::App (but installed via PSGI::Application)

	# teardown
	'teardown/Unrelated::App::teardown',                   # Unrelated::App (but installed via PSGI::Application)

);

is_deeply(\@Event_History, \@expected_events, 'Unrelated::App - callbacks executed correctly')
   or do {
		use	Data::Dumper;
		print STDERR "Actual Event History: \n";
		print STDERR Dumper	\@Event_History;
};

done_testing;
