
=head1 Everything::HTTP::Request

A request object for everything.

=cut

package Everything::HTTP::Request;

use Everything ('$DB');
use Everything::Auth;
use Everything::HTTP::ResponseFactory;

use CGI;
use strict;

use base 'Class::Accessor::Fast';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(
    qw/options initializer nodebase user user_vars cgi node system_vars theme authorisation response_type message/
);

=head1 Attributes

The object has the following attributes

=over 4

=item * node

The requested node

=item * nodebase

The nodebase to which this request relates

=item * authorisation

An Everything::Auth object

=item * user

The authorised user

=item * cgi

A CGI.pm object that relates to the request

=item * response_type

The type of the response object to be passed to the Response factory object.

=item * message

A message, such as an error, message to be picked up by other modules

=back



=cut

=head1 METHODS

The object supports the following methods

=head2 set_cgi_standard

This sets up the CGI object, taking data from the environment.

Returns self.

=cut

sub set_cgi_standard {
    my $self = shift;
    my $cgi;

    if ( $ENV{SCRIPT_NAME} ) {
        $cgi = CGI->new(@_);
    }
    else {
        $cgi = new CGI( \*STDIN, @_ );
    }

    if ( not defined( $cgi->param("op") ) ) {
        $cgi->param( "op", "" );
    }
    $self->set_cgi($cgi);
    return $self;
}

=cut

=head2 setup_standard_system_vars

This gets the 'system settings' node and assigns the settings hash to the
global HTMLVARS for our use during this page load.

=cut

sub setup_standard_system_vars {
    my $self = shift;

    # Get the HTML variables for the system.  These include what
    # pages to show when a node is not found (404-ish), when the
    # user is not allowed to view/edit a node, etc.  These are stored
    # in the dbase to make changing these values easy.
    my $SYSSETTINGS = $self->get_nodebase->getNode( 'system settings',
        $self->get_nodebase->getType('setting') );
    my $SETTINGS;
    if ( $SYSSETTINGS && ( $SETTINGS = $SYSSETTINGS->getVars() ) ) {
        $self->set_system_vars($SETTINGS) if ( ref $SETTINGS );
    }
    else {
        die "Error!  No system settings!";
    }
}

=cut





=head2 C<new>

This is the "main" function of Everything.  This gets called for each page load
in an Everything system.

=over 4

=item * $db

the string name of the database to get our information from.

=item * $options

optional options, see Everything::initEverything

=back

Returns nothing useful

=cut

sub new {
    my $class = shift;
    my $self = bless {}, $class;
    if (@_) {
        $self->setup_nodebase_object(@_);
    }
    return $self;
}

sub setup_nodebase_object {
    my $self = shift;
    my ( $db, $options, $initializer ) = @_;
    $$options{staticNodeTypes} ||= 1;
    Everything::initEverything( $db, $options );
    $self->set_options($options);
    $self->set_initializer($initializer);

    # The cache has a performance enhancement where it will only check
    # versions once.  This clears the version check cache so that we
    # will do fresh version checks each page load.
    $DB->resetNodeCache();

    $self->set_nodebase($DB);

}

sub execute_opcodes {
    my $self = shift;

    my @opcodes = $self->get_cgi->param('op');

    foreach my $op (@opcodes) {

        my $opcode = $self->get_nodebase->getNode( $op, 'opcode' );

        if ($opcode) {

            $opcode->run( { args => [ $self ] } );

        }
        elsif ( $op eq 'login' ) {
            Everything::HTML::opLogin( $self );
        }
        elsif ( $op eq 'logout' ) {
            Everything::HTML::opLogout( $self );
        }
        elsif ( $op eq 'nuke' ) {
            Everything::HTML::opNuke( $self );
        }
        elsif ( $op eq 'new' ) {
            Everything::HTML::opNew( $self );
        }
        elsif ( $op eq 'update' ) {
            Everything::HTML::opUpdate( $self );
        }
        elsif ( $op eq 'unlock' ) {
            Everything::HTML::opUnlock( $self );
        }
        elsif ( $op eq 'lock' ) {
            Everything::HTML::opLock( $self );
        }

    }

}

sub setup_everything_html {

    my $self = shift;
    $Everything::HTML::query = $self->get_cgi;

    tie $Everything::HTML::USER, "Everything::HTML::Environment::Variable",
      $self, 'user';
    tie $Everything::HTML::VARS, "Everything::HTML::Environment::Variable",
      $self, 'user_vars';
    tie $Everything::HTML::NODE, "Everything::HTML::Environment::Variable", $self, 'node';
    $Everything::HTML::GNODE = $Everything::HTML::NODE;
    *Everything::HTML::HTMLVARS = $self->get_system_vars;
    *Everything::HTML::GLOBAL   = {};
    $Everything::HTML::AUTH     = $self->get_authorisation;

}

=head2 C<set_node_from_cgi>

 This attempts to set the the node 'attribute' according to cgi rules. Takes the following arguments.

=over 4

=item * self

self explanatory

=item * reference to a callback subroutine

This is the subroutine that returns a node based on whether the cgi
parameter 'node' is present. If it is, returns a node of some description. If
undef a default is used.

=item * reference to a callback subroutine

If the cgi parameter 'node_id' is present this subroutine is called. It should return a node.

=back

This method calls the second argument of a 'node' parameter is
present, but if it is not present calls the third argument, but only
if the 'node_id' parameter is present.


 Returns nothing.

=cut

sub set_node_from_cgi {
    my ( $self, $node_name_cb, $node_id_cb ) = @_;
    my $cgi      = $self->get_cgi;
    my $nodebase = $self->get_nodebase;

    $node_name_cb ||= \&searchForNodeByName;

    $node_id_cb ||= sub {
        my ($node_id) = @_;
        $nodebase->getNode($node_id)
          || $nodebase->getNode( $self->get_system_vars->{notFound_node} );
    };

    my $node_id;
    if ( my $name = $cgi->param('node') ) {

        my $node = $node_name_cb->(
            {
                nodebase => $self->get_nodebase,
                user     => $self->get_user,
                name     => $name,
                types    => [ $self->get_cgi->param('type') ],
                e        => $self,
            }
        );
        $self->set_node($node);

    }
    elsif (  defined ( $node_id = $cgi->param('node_id') ) ) {

        my $node = $node_id_cb->($node_id);
        $self->set_node($node);
    }

    return;
}

sub authorise_user {
    my ( $self, $options ) = @_;
    $options->{EverythingRequest} = $self;

    my $auth_object = Everything::Auth->new($options);

    my ( $user, $vars ) = $auth_object->authUser();

    $self->set_user($user);
    $self->set_user_vars($vars);
    $self->set_authorisation($auth_object);
    return $self;

}

=head2 C<printHeader>

For each page we serve, we need to pass standard HTML header information.  If
we are script, we are responsible for doing this (the web server has no idea
what kind of information we are passing).

=over 4

=item * $datatype

(optional) the MIME type of the data that we are to display	('image/gif',
'text/html', etc).  If not provided, the header will default to 'text/html'.

=back

Returns nothing of value.

=cut

sub http_header {
    my ( $self, $arg ) = @_;

    my %headers = ();
    if ( ref $arg ) {
        %headers = %$arg;
    }
    else {
        $headers{-type} = $arg || 'text/html';
    }
    $headers{-cookie} = $self->get_user->{cookie} if $self->get_user->{cookie};
    if ( $ENV{SCRIPT_NAME} ) {
        my $headers = $self->get_cgi->header(%headers);
        return $headers;
    }
}

sub retrieve_node {
    my ( $nodebase, $node_id, $arg ) = @_;
    my $duplicates = $arg->{duplicates} if defined $arg->{duplicates};
    my $node = $nodebase->getNode($node_id);
    $node->{group} = $duplicates if $duplicates;
    return $node;
}

sub cleanNodeName {
    my ($nodename) = @_;

    $nodename =~ tr/[]|<>//d;
    $nodename =~ s/^\s*|\s*$//g;
    $nodename =~ s/\s+/ /g;
    $nodename = "" if $nodename =~ /^\W$/;

    #$nodename = substr ($nodename, 0, 80);

    return $nodename;
}

=head2 C<searchForNodeByName>

This looks for a node by the given name.  It returns a $node object. It takes a hash ref of the following name => value pairs.

=over 4

=item * name

the string name of the node we are looking for.

=item * use

the user object trying to view this node

=item * types

an array ref of type names we are lloing for

=item * nodebase

a nodebase object against which to do db queries

=item * e

the everything request object -- to be deprecated soon

=back



=cut

### we pass the $e object, because this has things like the GLOBAL
### attribute and'knows' about notFound_node, duplicates found etc.
### However, none of these things should be accessed here and should
### be passed ar args, in one form or another.
sub searchForNodeByName {
    my ($arg)    = @_;
    my $nodebase = $arg->{nodebase};
    my $name     = cleanNodeName( $arg->{name} );
    my $user     = $arg->{user};
    my $types    = $arg->{types};                   # array ref
    my $e        = $arg->{e};

    my @selecttypes = map { $nodebase->getId( $nodebase->getType($_) ) } @$types
      if @$types;

    my %selecthash = ( title => $name );

    $selecthash{type_nodetype} = \@selecttypes if @selecttypes;
    my $select_group = $nodebase->selectNodeWhere( \%selecthash );
    my $search_group;
    my $NODE;

    my $type = $$types[0];
    $type ||= "";

    if ( $select_group && @$select_group == 1 ) {

        # We found one exact match, goto it.
        my $node_id = $$select_group[0];
        return retrieve_node( $nodebase, $node_id );

    }
    elsif ( not $select_group or @$select_group == 0 ) {

        # We did not find an exact match, so do a search thats a little

        ### Bleh --- this is a sub pulled in from
        ### Everything.pm But the worst thing is that we need
        ### to access that horrid globals thing.  We shouldn't
        ### have access the $e object from here.

        $search_group = Everything::searchNodeName( $name, $types );

        if ( $search_group && @$search_group > 0 ) {
            my $node_id = $e->get_system_vars()->{searchResults_node};
            $e->set_message( $search_group );
            return retrieve_node( $nodebase, $node_id );
        }
        else {
            my $node_id = $e->get_system_vars()->{notFound_node};
            return retrieve_node( $nodebase, $node_id );
        }

    }

    else {
        my @canread = grep {
            my $N = $nodebase->getNode($_);
            $N->hasAccess( $user, 'r' );
        } @$select_group;

        unless (@canread) {
            my $node_id = $e->get_system_vars->{notFound_node};
            return retrieve_node( $nodebase, $node_id );
        }

        if ( @canread == 1 ) {
            return retrieve_node( $nodebase, $canread[0] );

        }

        #we found multiple nodes with that name.  ick
        my $node_id = $e->get_system_vars->{duplicatesFound_node};
        return retrieve_node( $nodebase, $node_id,
            { duplicates => \@canread } );

    }
}

package Everything::HTML::Environment::Variable;

sub TIESCALAR {
    my $class     = shift;
    my $request   = shift;
    my $attribute = shift;
    my $var       = { attribute => $attribute, request => $request };
    bless $var, $class;

}

sub FETCH {

    my $var       = shift;
    my $attribute = 'get_' . $var->{attribute};
    my $request   = $var->{request};
    return $request->$attribute;

}

sub STORE {
    my ( $var, $val ) = @_;
    my $attribute = $var->{attribute};
    my $request   = $var->{request};
    $request->{$attribute} = $val;

}

1;
