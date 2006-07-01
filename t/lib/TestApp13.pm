package TestApp13;
use strict;
use CGI::Application;
@TestApp13::ISA = qw(CGI::Application);

# Prevent output to STDOUT
$ENV{CGI_APP_RETURN_ONLY} = 1;

sub setup {
    my $self = shift;
    $self->run_modes( [ qw( mode1 mode2 ) ] );
    $self->start_mode( 'mode1' );
    $self->error_mode( 'error' );
}


sub mode1 {
    my $self = shift;
    my $file;
    open ( $file, "t/lib/templates/test.tmpl" )
      || die "Cannot open testing template";
    my $template = $self->load_tmpl( $file, 'die_on_bad_params' => 0 );
    $template->param( 'ping' => "HELLO!" );
    my $output = $template->output;
    close ( $file );
    $output;
}

sub mode2 {
    my $self = shift;
    my $template_string = <<_EOF_;
<html>
<head>
<title>Simple Test</title>
</head>
<body>
What's this: <!-- TMPL_VAR NAME="ping" -->
</body>
</html>
_EOF_

    my $template = $self->load_tmpl( \$template_string, 'die_on_bad_params' => 0 );
    $template->param( 'ping' => 'HELLO!' );
    $template->output;
}

sub error {
    my $self = shift;
    return "ERROR";
}

1;

