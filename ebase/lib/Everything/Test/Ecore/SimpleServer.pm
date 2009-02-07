
package Everything::Test::Ecore::SimpleServer;

use strict;
use warnings;

use SUPER;
use Everything::HTTP::CGI;

use base 'HTTP::Server::Simple::CGI';

sub new {
    my $class = shift;
    my $args = shift;
    my $port = $$args{listenport};
    my $self = $class->SUPER($port);
    $self->{mod_perlInit} = $$args{mod_perlInit};
    $self->{config} = $$args{config};

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

    my $args = $self->{config};

    Everything::HTTP::CGI->handle( $args );


}

1;
