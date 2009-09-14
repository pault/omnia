package Everything::HTTP::Response::stylesheet;

use base 'Everything::HTTP::Response::Htmlpage';

use strict;
use warnings;

sub select_htmlpage {

    my $this = shift;
    $this->get_request->get_cgi->param( displaytype => 'stylesheet' );
    $this->SUPER::select_htmlpage( @_ );

}

1;
