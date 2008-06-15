package Everything::HTTP::Response::Htmlpage;

use Everything::HTTP::Request;
use Encode;

use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
    qw/http_header http_body request htmlpage theme allowed redirect/);
use strict;

### because this is called from a Class::Factory object new is not
### called except by us.

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    $self->init(@_);
}

sub init {
    my ( $self, $e ) = @_;
    $self->set_request($e);
    $self->select_htmlpage;
    return $self;

}

sub create_http_body {
    my ( $self, $args )     = @_;
    my $htmlpage = $self->get_htmlpage;

    my $config = $$args{ config };
    my $ehtml = Everything::HTML->new;

    $ehtml->set_node_locators( $config->node_locations );
    $self->getTheme( $self->get_request );

    $ehtml->set_request( $self->get_request );
    $ehtml->set_htmlpage( $self->get_htmlpage );
    $ehtml->set_theme( $self->get_request->get_theme );

    unless ( $self->check_permissions ) {
        my $node =
          $self->get_request->get_nodebase->getNode( $self->get_redirect );
        $self->get_request->set_node($node);
        $self->select_htmlpage;

        die "Incorrect permissions!" unless $self->check_permissions;

    }

    return $self->set_http_body( encode( "utf8",
        $self->get_htmlpage->make_html( $self->get_request, $ehtml ) ) );

}

sub charset {
    'utf-8'

}

sub mime_type {

 $_[0]->get_htmlpage->{MIMEtype};

}

sub content_type {
    my $self = shift;
    my $type = $self->mime_type;
    if (  $type eq 'text/html' || $type eq 'text/xml' ) {
	return $type .';charset='. $self->charset;
    }

    return $type;

}

=head2 C<get_page_for_type>

Given a nodetype, get the htmlpages needed to display nodes of this type.  This
runs up the nodetype inheritance hierarchy until it finds something.

=over 4

=item * $TYPE

the nodetype hash to get display pages for.

=item * $displaytype

the type of display (usually 'display' or 'edit')

=back

Returns a node hashref to the page that can display nodes of this nodetype.

=cut

sub get_page_for_type {
    my ( $self, $TYPE, $displaytype ) = @_;
    my %WHEREHASH;
    my $PAGE;
    my $PAGETYPE;
    my $DB = $self->get_request->get_nodebase;

    $PAGETYPE = $DB->getType("htmlpage");
    $PAGETYPE or die "HTML PAGES NOT LOADED!";

    # Starting with the nodetype of the given node, We run up the
    # nodetype inheritance hierarchy looking for some nodetype that
    # does have a display page.
    do {

        # Clear the hash for a new search
        undef %WHEREHASH;

        %WHEREHASH = (
            pagetype_nodetype => $$TYPE{node_id},
            displaytype       => $displaytype
        );

        $PAGE = $DB->getNode( \%WHEREHASH, $PAGETYPE );

        if ( not defined $PAGE ) {
            if ( $$TYPE{extends_nodetype} ) {
                $TYPE = $DB->getType( $$TYPE{extends_nodetype} );
            }
            else {

                # No pages for the specified nodetype were found.
                # Use the default node display.
                $PAGE = $DB->getNode(
                    {
                        pagetype_nodetype => $DB->getType("node")->get_node_id,
                        displaytype       => $displaytype
                    },
                    $PAGETYPE
                );

                $PAGE
                  or die "No default pages loaded.  "
                  . "Failed on page request for $WHEREHASH{pagetype_nodetype}"
                  . " $WHEREHASH{displaytype}, $!\n";
            }
        }
    } until ($PAGE);

    return $PAGE;
}

sub check_permissions {

    my $self  = shift;
    my $PAGE  = $self->get_htmlpage;
    my $E     = $self->get_request;
    my $NODE  = $E->get_node;
    my $user  = $E->get_user;
    my $query = $E->get_cgi;
    my $permission_needed =  $PAGE->get_permissionneeded();

    # If the user does not have the needed permission to view this
    # node through the desired htmlpage, we send them to the permission
    # denied node.

    #Also check to see if the particular displaytype can be executed by the user

    unless ($NODE->hasAccess( $user, $permission_needed )
        and $PAGE->hasAccess( $user, "x" ) )
    {

        # Make sure the display type is set to display.  Otherwise we
        # may get stuck in an infinite loop of permission denied.
        $query->param( "displaytype", "display" );

        $self->set_redirect( $E->get_system_vars->{permissionDenied_node} );
        return $self->set_allowed(0);
    }

    if ( $permission_needed eq "w" ) {

        # If this is an "edit" page.  We need to lock the node while
        # this user is editing.
        if ( not $NODE->lock( $E->get_user ) ) {

            # Someone else already has a lock on this node, go to the
            # "node locked" node.
            $query->param( 'displaytype', 'display' );
            $self->set_redirect( $E->get_system_vars->{nodeLocked_node} );
            return $self->set_allowed(0);
        }
    }

    return $self->set_allowed(1);

}

sub select_htmlpage {

    my $this = shift;
    my $E    = $this->get_request;
    my $DB   = $E->get_nodebase;
    my $NODE = $E->get_node;

    my $THEME       = $E->get_theme;
    my $VARS        = $E->get_user_vars();
    my $query       = $E->get_cgi;
    my $displaytype = $query->param('displaytype');

    #	my ($NODE, $displaytype) = @_;
    my $TYPE;

    $TYPE = $DB->getType( $NODE->get_type_nodetype );
    $displaytype ||= $$VARS{ 'displaypref_' . $$TYPE{title} }
      if exists $$VARS{ 'displaypref_' . $$TYPE{title} };
    $displaytype ||= $$THEME{ 'displaypref_' . $$TYPE{title} }
      if exists $$THEME{ 'displaypref_' . $$TYPE{title} };
    $displaytype ||= 'display';

    my $PAGE;

    # First, we try to find the htmlpage for the desired display type,
    # if one does not exist, we default to using the display page.
    $PAGE ||= $this->get_page_for_type( $TYPE, $displaytype );

    die "Can't load a page $displaytype for $$TYPE{title} type" unless $PAGE;

    $this->set_htmlpage($PAGE);

}

=head2 C<getTheme>

This creates the $THEME variable that various components can reference for
detailed settings.  The user's theme is a system-wide default theme if not
specified, then a "themesetting" can be used to override specific values.
Finally, if there are user-specific settings, they are kept in the user's
settings.

Returns blank string if it succeeds, undef if it fails.

=cut

sub getTheme {
    my ( $self, $e ) = @_;
    my $THEME;
    my $theme_id;
    $theme_id = $e->get_user_vars()->{preferred_theme}
      if ( exists $e->get_user_vars->{preferred_theme} );

    $theme_id ||= $e->get_system_vars()->{default_theme};
    my $TS = $e->get_nodebase->getNode($theme_id);

    if ( $TS->isOfType('themesetting') ) {

        # We are referencing a theme setting.
        my $BASETHEME = $e->get_nodebase->getNode( $$TS{parent_theme} );

        my $REPLACEMENTVARS;
        my $TEMPTHEME;

        return undef unless ($BASETHEME);

        $TEMPTHEME       = $BASETHEME->getVars();
        $REPLACEMENTVARS = $TS->getVars();

        # Make a copy of the base theme vars.  We don't want to modify
        # the actual node.
        undef %$THEME;
        @$THEME{ keys %$TEMPTHEME }       = values %$TEMPTHEME;
        @$THEME{ keys %$REPLACEMENTVARS } = values %$REPLACEMENTVARS;
    }
    elsif ( $TS->isOfType('theme') ) {

        # This whatchamacallit is a theme
        $THEME = $TS->getVars();
    }
    else {
        die "Node $theme_id is not a theme or themesetting!";
    }

    $Everything::HTML::THEME = $THEME;
    return $e->set_theme($THEME);
}




1;
