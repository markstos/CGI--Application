# $Id: test.pl,v 1.5 2000/07/18 21:04:46 jesse Exp $
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .
# (It may become useful if the test is moved to ./t subdirectory.)

BEGIN { $| = 1; print "1..9\n"; }
END {print "not ok 1\n" unless $loaded;}
use CGI::Application;
$loaded = 1;
print "ok 1\n";

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

# bring in testing hierarchy
use lib './test';
use TestApp;

$ENV{CGI_APP_RETURN_ONLY} = 1;

# Test 2: Instantiate CGI::Application
my $ca_obj = CGI::Application->new();
if ((ref($ca_obj) && $ca_obj->isa('CGI::Application'))) {
	print "ok 2\n";
} else {
	print "not ok 2\n";
}


# Test 3: run() CGI::Application object.  Expect header + output dump_html()
$ca_obj->query(CGI->new(""));
my $t3_output = $ca_obj->run();
if (($t3_output =~ /^Content\-Type\:\ text\/html/) && ($t3_output =~ /Query\ Environment\:/)) {
	print "ok 3\n";
} else {
	print "not ok 3\n";
}


# Test 4: Instantiate CGI::Application sub-class.
my $ta_obj = TestApp->new(QUERY=>CGI->new(""));
if ((ref($ta_obj) && $ta_obj->isa('CGI::Application'))) {
	print "ok 4\n";
} else {
	print "not ok 4\n";
}


# Test 5: run() CGI::Application sub-class.  Expect HTTP header + 'Hello World: basic_test'.
my $t5_output = $ta_obj->run();
if (($t5_output =~ /^Content\-Type\:\ text\/html/) && ($t5_output =~ /Hello\ World\:\ basic\_test/)) {
	print "ok 5\n";
} else {
	print "not ok 5\n";
}


# Test 6: run() CGI::Application sub-class, in run-mode 'redirect_test'.  Expect HTTP redirect header + 'Hello World: redirect_test'.
my $t6_ta_obj = TestApp->new();
$t6_ta_obj->query(CGI->new({'test_rm' => 'redirect_test'}));
my $t6_output = $t6_ta_obj->run();
if (($t6_output =~ /^Status\:\ 302\ Moved/) && ($t6_output =~ /Hello\ World\:\ redirect\_test/)) {
	print "ok 6\n";
} else {
	print "not ok 6\n";
}


# Test 7: run() CGI::Application sub-class, in run-mode 'cookie_test'.  Expect HTTP header w/ cookie 'c_name' => 'c_value' + 'Hello World: cookie_test'.
my $t7_ta_obj = TestApp->new();
$t7_ta_obj->query(CGI->new({'test_rm' => 'cookie_test'}));
my $t7_output = $t7_ta_obj->run();
if (($t7_output =~ /^Set-Cookie\:\ c\_name\=c\_value/) && ($t7_output =~ /Hello\ World\:\ cookie\_test/)) {
	print "ok 7\n";
} else {
	print "not ok 7\n";
}


# Test 8: run() CGI::Application sub-class, in run-mode 'tmpl_test'.  Expect HTTP header + 'Hello World: tmpl_test'.
my $t8_ta_obj = TestApp->new(TMPL_PATH=>'test/templates/');
$t8_ta_obj->query(CGI->new({'test_rm' => 'tmpl_test'}));
my $t8_output = $t8_ta_obj->run();
if (($t8_output =~ /^Content\-Type\:\ text\/html/) && ($t8_output =~ /\-\-\-\-\>Hello\ World\:\ tmpl\_test\<\-\-\-\-/)) {
	print "ok 8\n";
} else {
	print "not ok 8\n";
}


# Test 9: run() CGI::Application sub-class, in run-mode 'tmpl_badparam_test'.  Expect HTTP header + 'Hello World: tmpl_badparam_test'.
my $t9_ta_obj = TestApp->new(TMPL_PATH=>'test/templates/');
$t9_ta_obj->query(CGI->new({'test_rm' => 'tmpl_badparam_test'}));
my $t9_output = $t9_ta_obj->run();
if (($t9_output =~ /^Content\-Type\:\ text\/html/) && ($t9_output =~ /\-\-\-\-\>Hello\ World\:\ tmpl\_badparam\_test\<\-\-\-\-/)) {
	print "ok 9\n";
} else {
	print "not ok 9\n";
}

# All done!
