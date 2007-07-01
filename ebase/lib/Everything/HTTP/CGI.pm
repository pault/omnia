package Everything::HTTP::CGI;

use strict;
use warnings;
use Everything::HTTP::Request;

sub handle  {
    my ( $self, $db_string, $db_options ) = @_;

    my $e = Everything::HTTP::Request->new($db_string, $db_options);

    ## sets up variables for serving web pages mostly pulled from db
    $e->setup_standard_system_vars();

    ## get a CGI object
    $e->set_cgi_standard( $e->get_initializer );

    ## Log the user in
    my $options = $e->get_options;
    $options->{query}    = $e->get_cgi;
    $options->{nodebase} = $e->get_nodebase;
    $e->authorise_user($options);

    ## execute options
    # Execute any operations that we may have

    $e->set_node_from_cgi;

    if ( !$e->get_node ) {
        my $node =
          $e->get_nodebase->getNode(
            $e->get_system_vars->{default_node} );
        $e->set_node($node);

    }

    $e->setup_everything_html;

    $e->execute_opcodes;

    my $response = Everything::HTTP::ResponseFactory->new( 'htmlpage', $e );
    $response->create_http_body;
    my $html   = $response->get_http_body;
    my $header = $e->http_header( $response->get_mime_type );

    $e->get_cgi->print($header);
    $e->get_cgi->print($html);

    $e->get_user->setVars( $e->get_user_vars, $e->get_user );
    $e->get_user->update( $e->get_user );

}

1;
