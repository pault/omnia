package Everything::HTTP::Apache;

use Apache2::Const ':common';
use Apache2::RequestRec ();
use Everything::HTTP::Request;
use Everything::HTTP::URL::Deconstruct;
use Everything::HTTP::URL;
use Everything::HTTP::ResponseFactory;
use strict;
use warnings;

## initialise
Everything::HTTP::URL->set_default_sub( \&Everything::HTML::linkNode );

sub handler {

    my $r        = shift;
    my $db       = $r->dir_config->get('everything-database');
    my $user     = $r->dir_config->get('everything-database-user');
    my $password = $r->dir_config->get('everything-database-password') || '';
    my $host     = $r->dir_config->get('everything-database-host');
    my %options  = $r->dir_config->get('everything-database-options');

    ## scriptname for CGI
    my $e =
      Everything::HTTP::Request->new( "$db:$user:$password:$host", \%options );
    create_url_parsers( $r, $e )
      unless Everything::HTTP::URL->isset_url_parsers;

    ## sets up variables for serving web pages mostly pulled from db

    $e->setup_standard_system_vars();

    ## get a CGI object
    $e->set_cgi_standard();

    ## Log the user in
    my $options = $e->get_options;
    $options->{nodebase} = $e->get_nodebase;
    $options->{query}    = $e->get_cgi;
    $e->authorise_user($options);

    ## VARIABLES
    $e->setup_everything_html;

    $e->execute_opcodes;

    $e->set_node_from_cgi;

    if ( !$e->get_node ) {
        my $node = Everything::HTTP::URL->parse_url($r);

        if ( $node && !ref $node ) {
            return NOT_FOUND;
        }
        else {
            $e->set_node($node);
        }
    }

    ### if we haven't returned find the default node
    if ( !$e->get_node && ( $r->path_info eq '/' || $r->path_info eq '' ) ) {
        my $default_node_id = $e->get_system_vars->{default_node};
        my $default_node    = $e->get_nodebase->getNode($default_node_id);
        $e->set_node($default_node);
    }

    ### if we haven't returned and still don't have a node ref, we
    ### obviously are pointing to a non-existent location.

    return NOT_FOUND unless ref $e->get_node;

    $e->setup_everything_html;

    ### XXX- set in config file response factory
    ### XXX- response factory should set up the environment that htmlpage needs

    my $response = Everything::HTTP::ResponseFactory->new( 'htmlpage', $e );
    $response->create_http_body;
    my $html = $response->get_http_body;

    $r->content_type( $response->get_mime_type );

    $r->headers_out->set( 'Set-Cookie' => $e->get_user->{cookie} );

    $r->print($html);

    # To ensure any changes in VARS are saved to the db
    $e->get_user->setVars( $e->get_user_vars, $e->get_user );
    $e->get_user->update( $e->get_user );

    return OK;

}

sub create_url_parsers {
    my ( $r, $e ) = @_;

    ## parse the URL
    ## setup url processing

    my @url_config = $r->dir_config->get('everything-url');
    return unless @url_config;

    while ( my ( $schema, $linker_arg ) = splice( @url_config, 0, 2 ) ) {

        my $url_parser = Everything::HTTP::URL::Deconstruct->new(
            {
                nodebase => $e->get_nodebase,
                location => $r->location,
                request  => $e
            }
        );
        $url_parser->set_schema($schema);
        $url_parser->make_url_gen;
        $url_parser->register_url_parser;
        $url_parser->create_nodetype_rule( $url_parser->make_link_node,
            $linker_arg );
    }
    no warnings 'redefine';
    *Everything::HTML::linkNode = Everything::HTTP::URL->create_linknode;

}

1;