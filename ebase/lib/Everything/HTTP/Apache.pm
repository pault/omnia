package Everything::HTTP::Apache;

use Apache2::Const ':common';
use Apache2::RequestRec ();
use Everything::HTTP::Request;
use Everything::HTTP::ResponseFactory;
use Everything::HTML;
use Everything::Config;
use strict;
use warnings;

use Carp;

#BEGIN { $SIG{__WARN__} = \&Carp::cluck;}

sub handler {

    my $r        = shift;

    my $config =  Everything::Config->new( apache_request => $r );
    my $e =
      Everything::HTTP::Request->new( $config );

    $e->get_nodebase->resetNodeCache;

    ## sets up variables for serving web pages mostly pulled from db

    $e->set_system_vars( $config->htmlvars() );

    ## get a CGI object
    $e->set_cgi_standard();

    ## Log the user in
    my $options = $e->get_options;
    $options->{nodebase} = $e->get_nodebase;
    $options->{query}    = $e->get_cgi;
    $e->authorise_user($options);

    $e->execute_opcodes;

    unless ( $e->get_node ) {
	$e->set_node_from_cgi;
    }

    if ( !$e->get_node && $r->uri ) {

        modify_request( $config, $r->uri, $e );

        my $node = $e->get_node;

        if ( $node && !ref $node ) {
            return NOT_FOUND;
        }
    }

    if ( $r->uri ne '/' && ! $e->get_node ) {
	return NOT_FOUND
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

    ### XXX- set in config file response factory
    ### XXX- response factory should set up the environment that htmlpage needs

    my $response = Everything::HTTP::ResponseFactory->new( $e->get_response_type || 'htmlpage',  { config => $config, request => $e } );
    
    my $html = $response->content();

    $r->content_type( $response->content_type );

    $r->headers_out->set( 'Set-Cookie' => $e->get_user->{cookie} );

    my %headers = $response->headers;

    foreach ( keys %headers ) {
	$r->headers_out->set( $_ => $headers{ $_ } );
    }

    $r->print($html);

    # XXX: These should be set in the Response object
    # NB: These lines ensure any changes in VARS are saved to the db
    $e->get_user->setVars( $e->get_user_vars, $e->get_user );
    $e->get_user->update( $e->get_user );

    return $response->status_code;

}


sub modify_request {
    my ( $config, $url, $e ) = @_;

    my @request_modifiers = @{ $config->request_modifiers };
    return unless @request_modifiers;

    my $found = 0;

    foreach ( @request_modifiers ) {
	$found++  if $_->( $url, $e );
	last if $found;
    }

    return $found if $found;
    return;
}


sub create_url_parsers {
    my ( $r, $e, $ehtml ) = @_;

    ## parse the URL
    ## setup url processing

    Everything::HTTP::URL->clear_request_modifiers;
    Everything::HTTP::URL->clear_node_to_url_subs;

    my @url_config = $r->dir_config->get('everything-url');

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
        $url_parser->make_modify_request;
        $url_parser->create_nodetype_rule( $url_parser->make_link_node,
            $linker_arg );
    }

    my $link_node = Everything::HTTP::URL->create_linknode;
    no warnings 'redefine';

    *Everything::HTML::linkNode = sub {
        my $node = shift;
        $Everything::DB->getRef($node);
        $link_node->( $node, @_ );
    };
    use warnings 'redefine';

    my $link_node_sub = sub {
        my $self = shift;
        my $node = shift;
        $self->get_nodebase->getRef($node);
        $link_node->( $node, @_ );
    };

    $ehtml->set_link_node_sub($link_node_sub);
}

1;
