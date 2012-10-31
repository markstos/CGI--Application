package TestCGI;
use Any::Moose;
extends 'CGI::PSGI';

# sub header {
# 	my $self = shift;
# 	# carp("TestCGI proxy method 'header'");
# 	return $self->{CGI}->header(@_);
# }
# 
# 
# sub redirect {
# 	my $self = shift;
# 	# carp("TestCGI proxy method 'redirect'");
# 	return $self->{CGI}->redirect(@_);
# }
# 
# 
sub param {
 	my $self = shift;
    my @args = shift;
    no warnings;
    if ((scalar @args == 1) && ($args[0] eq 'rm')) {
        return 'testcgi_mode';
    }
    else {
        return $self->SUPER::param(@args);
    }
}


1;


