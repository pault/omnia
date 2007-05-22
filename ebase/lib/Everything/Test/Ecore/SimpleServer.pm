
package Everything::Test::Ecore::SimpleServer;

use SUPER;
use Everything::HTML qw/mod_perlInit/;

use base 'HTTP::Server::Simple::CGI';

sub new {
    my $class = shift;
    my $args = shift;
    my $port = $$args{listenport};
    my $self = $class->SUPER($port);
    $self->{mod_perlInit} = $$args{mod_perlInit};

    ## to deal with unwanted behaviour
    $Everything::commandLine = 0;

    return $self;
}

sub handle_request {
    my ( $self, $cgi ) = @_;
    print "HTTP/1.0 200 OK\n";

    ## to stop Everything::HTML::getGCI from hanging and other oddness
    $ENV{SCRIPT_NAME} = $0;
    local *Everything::HTML::getCGI;
    *Everything::HTML::getCGI = sub { $cgi };

    my $args = $self->{mod_perlInit};

    mod_perlInit( @$args );


}

1;
