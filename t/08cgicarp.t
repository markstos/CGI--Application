# $Header: /home/mark/cgi-app/CGIAPP_CVSROOT/CGI-Application/t/Attic/08cgicarp.t,v 1.1 2004/01/31 23:33:25 mark Exp $
# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl test.pl'

######################### We start with some black magic to print on failure.

# Change 1..1 below to 1..last_test_to_print .

BEGIN { $| = 1; print "1..2\n"; }

use CGI::Application qw(-nocgicarp);


# CGI::Carp shouldn't be loaded
if ($INC{'CGI/Carp.pm'}) {
    print "not ok 1\n";
}
else {
    print "ok 1\n";
}


# .. but Carp still should be. 
if ($INC{'Carp.pm'}) {
    print "ok 2\n";
}
else {
    print "not ok 2\n";
}

# All done!
