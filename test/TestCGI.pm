package TestCGI;

use CGI;
use CGI::Carp;

sub new {
	my $pkg = shift;
	my $self = {};
	bless($self, $pkg);

	my $q = CGI->new();
	$self->{CGI} = $q;

	# Set test value
	$q->param('rm', 'testcgi_mode');

	return $self;
}


sub header {
	my $self = shift;

	# carp("TestCGI proxy method 'header'");

	return $self->{CGI}->header(@_);
}


sub redirect {
	my $self = shift;

	# carp("TestCGI proxy method 'redirect'");

	return $self->{CGI}->redirect(@_);
}


sub param {
	my $self = shift;

	# carp("TestCGI proxy method 'param'");

	return $self->{CGI}->param(@_);
}


1;


