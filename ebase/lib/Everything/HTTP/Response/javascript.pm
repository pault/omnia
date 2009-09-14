package Everything::HTTP::Response::javascript;

use base 'Everything::HTTP::Response::Htmlpage';

use strict;
use warnings;

sub select_htmlpage {

    my $this = shift;
    $this->get_request->get_cgi->param( displaytype => 'javascript' );
    $this->SUPER::select_htmlpage( @_ );

}

1;
