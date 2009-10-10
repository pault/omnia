
=head1 Everything::Node

The basic class that implements the node object.

All methods in this package are intended to be methods that pertain to nodes of
*ALL* types.  If a method is needed by a specific nodetype, it must be
implemented in its own package, or implemented as a nodemethod.  Methods in
this package have the performance benefit of not having to go through AUTOLOAD.
However, if the method is not used by all nodetypes, it must go in its own
package.

Copyright 2000 - 2003 Everything Development Inc.

=cut

package Everything::Node;

#	Format: tabs = 4 spaces

use strict;
use Everything ();
use Everything::Util ();
use XML::DOM;
use Scalar::Util qw/blessed/;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Object';

has _type => ( accessor => '_type' );
has access => ( is => 'rw', isa => 'Everything::NodeAccess', handles => { hasAccess => 'has_access' });
has nodebase => ( is => 'rw' );
has DB => ( is => 'rw' );
has nocache => ( is => 'rw' );

=cut


=head2 C<new>

"Constructor" for the Node object.  This takes the given node hash and just
blesses it.  This should only be called by NodeBase when it retrieves the nodes
from the database to "objectify" them.

=over 4

=item * $NODE

a reference to the node hash to bless, not an id or name!

=item * $DB

when NodeBase.pm calls this, it passes a ref to itself so that when we
implement these methods, we can access the basic sql functions.

=item * $nocache

(optional) True if the new node should not be cached.  Preferably pass
'nocache', so that it's obvious what you are doing.

=back

=cut

=head2 C<DESTROY>

Gets called by perl when an object is about to be freed.  We delete any
pointers that we have to get rid of possible circular references.

=cut

sub DESTROY
{
	my ($this) = @_;

	# Problem here is that the nodetype that is pointed to by $$this{type}
	# could get destructed first on shutdown which would make this
	# malfunction.  Disabling for now since this may not really be needed.
	#$this->destruct();

	# Remove any references that we may have.  Probably not necessary,
	# but will prevent the possibility any circular references.
	delete $$this{type};
	delete $$this{DB};
	delete $$this{SUPERtype};
	delete $$this{SUPERparams};
	delete $$this{SUPERfunc};
}

=cut


=head2 C<getId>

Gets the numeric id of this object.

Returns duh

=cut

sub getId
{
	my ($this) = @_;
	return $$this{node_id};
}

=head2 C<getNodeMethod>

This is a utility function that finds the method of the given name for the
given type.  This searches for 'nodemethod' nodetypes and the installed .pm
implementations.  If it does not find one for that type, it will run up the
nodetype inheritence hierarchy until it finds one, or determines that one does
not exist.

=over 4

=item * $func

the name of the method/function to find

=item * $TYPE

the type of the node that is looking for this function

=back

Returns a hash structure that contains the method if found.  undef if no method
is found.  The hash returned has a 'type' field which is either "nodemethod',
or 'pm'.  Where 'nodemethod' indicates that the function was found in a
nodemethod node, and 'pm' indicates that it found the function implemented in a
.pm file.  See the code for the hash structures (grin).

=cut

sub getNodeMethod
{
        Everything->deprecate( "Don't call node methods from inside a node" );
	my ( $this, $func, $TYPE ) = @_;
	my $METHODTYPE;
	my $METHOD;
	my $RETURN;
	my $found     = 0;
	my $cacheName = $$TYPE{title} . ":" . $func;

	# If we have it cached, return what we found
	$METHOD = $this->{DB}->{cache}->{methodCache}{$cacheName}
		if exists $this->{DB}->{cache}->{methodCache}{$cacheName};
	return $METHOD if $METHOD;

	$METHODTYPE = $$this{DB}->getType('nodemethod');

	if ($METHODTYPE)
	{

		# First check to see if a nodemethod exists for this type.
		$METHOD = $$this{DB}->getNodeWhere(
			{
				'title'             => $func,
				'supports_nodetype' => $$TYPE{node_id}
			},
			$METHODTYPE
		);
		$METHOD = shift @$METHOD;
	}

	if ( not $METHOD )
	{

		# Ok, we don't have a nodemethod.  Check to see if we have
		# the function implemented in a .pm
		my $name = $$TYPE{title};
		$name =~ s/\W//g;
		my $package = "Everything::Node::$name";

		$found = $package->can($func)
			if ( exists $this->{DB}->{nodetypeModules}->{$package} );

		if ($found)
		{

			# We need to call a function that exists in a pm.
			$RETURN = {
				'SUPERtype' => $$TYPE{node_id},
				'type'      => "pm",
				'name'      => $package . "::" . $func
			};
		}
	}
	else
	{

		# The stuff is stored in the node.
		$RETURN = {
			'SUPERtype' => $$TYPE{node_id},
			'type'      => 'nodemethod',
			'node'      => $METHOD->getId()
		};
		$found = 1;
	}

	if ( ( not $found ) && ( $TYPE = $TYPE->getParentType() ) )
	{

		# Move up the inheritence hierarchy and recursively call this.
		$RETURN = $this->getNodeMethod( $func, $TYPE );
	}

	# Cache what we found for future reference.  However, only cache it
	# if we actually found something.
	$this->{DB}->{cache}->{methodCache}{$cacheName} = $RETURN if ($RETURN);

	return $RETURN;
}

=cut


=head2 C<getClone>

Clone this node!  This will make an exact duplicate of this node and insert it
into the database.  The only difference is that the cloned node will have a
different ID.

If sub types have special data (ie nodegroups) that would also need to be
cloned, they should override this function to do       that work.

=over 4

=item * $title

the new title of the cloned node

=item * $USER

the user trying to clone this node (for permissions)

=item * $workspace

the id or workspace hash into which this node should be cloned.  This is
primarily for internal purposes and should not be used normally.  (NOT
IMPLEMENTED YET!)

=back

Returns the newly cloned node, if successful.  undef otherwise.

=cut

sub getClone
{
	my ( $this, $title, $USER, $workspace, $nodebase) = @_;
	my $CLONE;
	my $create;

	$create = "create" if ( $nodebase->storage_settings( $this )->{restrictdupes} );
	$create ||= "create force";

	$CLONE = $nodebase->getNode( $title, $this->type_title, $create );

	# if the id is not zero, the getNode found a node that already exists
	# and the type does not allow duplicate names.
	return if ( $$CLONE{node_id} > 0 );

	return unless $CLONE->clone( $this, $USER );

	return $CLONE;

}

=cut

=head2 C<assignType>

This is an "private" function that should never be needed to be called from
outside packages.  This just assigns the node's type to the {type} field of the
hash.

=cut

sub assignType
{
	my ($this) = @_;

	my $nodebase = $$this{DB} || $$this{nodebase};

	if ( $$this{node_id} == 1 )
	{
		$$this{type} = $this;
	}
	else
	{
		$$this{type} = $nodebase->getType( $$this{type_nodetype} );
	}

}

=cut


=head2 C<cache>

Cache this node in the node cache (say that real fast 3 times).

Returns result of cacheNode call (pretty much guaranteed to be 1)

=cut

sub cache
{
	my ($this) = @_;
	Everything->deprecate('Call cacheNode on the object stored in nodebase');
	return unless ( defined $$this{DB}->{cache} );
	$$this{DB}->{cache}->cacheNode($this);
}

=cut


=head2 C<removeFromCache>

Remove this object from the cache.

Returns result of removeNode call (pretty much guaranteed to be 1)

=cut

sub removeFromCache
{
	my ($this) = @_;
	Everything->deprecate('Call removeNode on the object stored in nodebase');
	return unless ( defined $$this{DB}->{cache} );
	$$this{DB}->{cache}->removeNode($this);
}

=cut


=head2 C<quoteField>

Quick way to quote a specific field on this object so that it does not affect
the sql query.

=over 4

=item * $field

the field of this object to quote (ie 

  $this-E<gt>quoteField("title");

=back

Returns the field in a quoted string form.

=cut

sub quoteField
{

    Everything->deprecate('Use Everything::DB');
	my ( $this, $field ) = @_;
	return ( $$this{DB}->{dbh}->quote( $$this{$field} ) );
}

=cut


=head2 C<isOfType>

Checks to see if a node is of a certain type.

=over 4

=item * $type

a nodetype node, numeric id, or string name of a type

=item * $recurse

Nodetypes can derive from other nodetypes.  Superdoc derives from document, and
restricted_superdoc derives from superdoc.  If you have a superdoc and you ask
isOfType('document'), you will get false unless you turn on the recurse flag.
If you don't turn it on, its an easy way to see if a node is of a specific type
(by name, etc).  If you turn it on, its good to see if a node is of the
specified type or somehow derives from that type.

=back

Returns true if the node is of the specified type.  False otherwise.

=cut

sub isOfType
{
	my ( $this, $type, $recurse ) = @_;

	return 0 unless '$type';

	return 1 if ( $this->isa( "Everything::Node::$type" ) );

	return 0;
}

=cut


=head2 C<lock>

For race condition purposes.  This marks a node as "locked" so that others
cannot access it.

*** NOTE *** Not implemented!

Returns true if the lock was granted.  False if otherwise.

=cut

sub lock
{
	my ( $this, $USER ) = @_;

	return 1;
}

=cut


=head2 C<unlock>

This removes the "lock" flag from a node.

*** NOTE *** Not implemented!

Returns true if the lock was removed.  False if not (usually means that you did
not have the lock in the first place).

=cut

sub unlock
{
	my ( $this, $USER ) = @_;

	return 1;
}

=cut


=head2 C<updateLinks>

A link has been traversed.  If it exists, increment its hit and food count.  If
it does not exist, add it.

=over 4

=item * $this

(the object) the node that the link goes to

=item * $FROMNODE

the node the link comes from

=item * $type

the type of the link, can either refer to a nodetype, or be an arbitrary int
value

=back

Returns 1 if successful	

=cut

sub updateLinks
{
	my ( $this, $FROMNODE, $type ) = @_;

	return unless ($FROMNODE);
	return if ( $$this{node_id} == $$this{DB}->getId($FROMNODE) );

	$type ||= 0;

	my $to_id   = $$this{node_id};
	my $from_id = $$this{DB}->getId($FROMNODE);

	my $rows =
		$this->{DB}->sqlSelect( 'count(*)', 'links',
		'to_node = ? AND from_node = ? AND linktype = ?',
		'', [ $to_id, $from_id, $type ] );

	# '0E0' returned from the DBI indicates successful statement execution
	# with 0 rows affected.  They just didn't like '0 but true'.
	if ( $rows and $rows ne '0E0' )
	{
		$this->{DB}->sqlUpdate(
			'links',
			{ -hits => 'hits+1', -food => 'food+1' },
			'from_node = ? AND to_node = ? AND linktype= ?',
			[ $from_id, $to_id, $type ]
		);
	}
	else
	{
		my $atts = {
			food      => 500,
			hits      => 1,
			to_node   => $to_id,
			linktype  => $type,
			from_node => $from_id,
		};
		$this->{DB}->sqlInsert( 'links', $atts );

		@$atts{qw( from_node to_node )} = @$atts{qw( to_node from_node )};
		$this->{DB}->sqlInsert( 'links', $atts ) unless $type;
	}
	'';
}

=cut


=head2 C<updateHits>

Increment the number of hits on a node.

=over 4

=item * $NODE

the node in which to update the hits on

=back

Returns the new number of hits

=cut

sub updateHits
{
	my ($this) = @_;
	Everything->deprecate( "Nodes don't know about their hits, call from frontend");
	my $id = $$this{node_id};

	$$this{DB}->sqlUpdate( 'node', { -hits => 'hits+1' }, "node_id=$id" );

	# We will just do this, instead of doing a complete refresh of the node.
	++$$this{hits};
}

=cut


=head2 C<getLinks>

Gets an array of hashes for the links that originate from this node.

=over 4

=item * $orderby

the field in which the sql should order the list

=back

Returns a reference to an array that contains the links

=cut

sub selectLinks
{
	my ( $this, $orderby ) = @_;
	Everything->deprecate( "Nodes can't get their own links, select from frontend");
	my $obstr = $orderby ? " ORDER BY $orderby" : '';

	my $cursor =
		$this->{DB}->sqlSelectMany( '*', 'links', 'from_node=?', $obstr,
		[ $this->{node_id} ] );

	return unless $cursor;

	my @links;
	while ( my $linkref = $cursor->fetchrow_hashref() )
	{
		push @links, $linkref;
	}

	$cursor->finish();

	return \@links;
}

=cut


=head2 C<getTables>

Get the tables that this node needs to join on to be created.

=over 4

=item * $nodetable

pass 1 (true) if you want the node table included in the array (the node table
is usually assumed so it is not included).  pass undef (nothing) or 0 (zero) if
you don't need the node table.

=back

Returns an array ref of the table names that this node joins on.  Note that the
array is a copy of the internal data structures.  Feel free to change it or
what ever you need to do.

=cut

sub getTables
{
	my ( $this, $nodetable ) = @_;
	Everything->deprecate( "Nodes don't know about the tables they are stored in use the methods in Everything::DB" );
	return $this->type->getTableArray($nodetable);
}

=cut


=head2 C<getHash>

General purpose function to get a hash structure from a field in the node.

=over 4

=item * $field

the field to hashify from the node

=back

Returns hash reference, if found, undef if not.

=cut

sub getHash
{
	my ( $this, $field ) = @_;
	my $store = "hash_" . $field;

	return $this->{$store} if exists $this->{$store};

	unless ( exists $this->{$field} )
	{
		Everything::logErrors( "Node::getHash:\t'$field' field does not "
				. "exist for node $this->{node_id}, '$this->{title}'" );
		return;
	}

	# some code depends on having the reference stored in cache, even
	# if hashified field is empty
	unless ( $this->{$field} )
	{
		my %empty;
		return $this->{$store} = \%empty;
	}

	# We haven't retrieved the hash yet... do it.
	my %vars = map { split /=/ } split( /&/, $this->{$field} );

	foreach ( keys %vars )
	{
		$vars{$_} = Everything::Util::unescape( $vars{$_} );
		$vars{$_} = '' unless $vars{$_} =~ /\S/;
	}

	return $this->{$store} = \%vars;
}

=cut


=head2 C<setHash>

This takes a hash of variables and assigns it to the 'vars' of the given node.
If the new vars are different, we will update the node.

NOTE!  If the vars hash contains an undefined value or the value is an empty
string, it will be removed from the hash as it would generate a string like:

  key1=value1&key2=&key3=value3

When we try to reconstruct the hash in getHash, it will fail because of the
'key2=' blank value.  So, just be aware that setting a hash may cause a key to
be deleted.

=over 4

=item * $varsref

the hashref to get the vars from

=item * $field

the field of the node to set.  Different types may store their hashes in
different places.

=back

Returns nothing.

=cut

sub setHash
{
	my ( $this, $varsref, $field ) = @_;
	my $store = "hash_" . $field;

	# Clean out the keys that have do not have a value.
	# we use defined() because 0 is a valid value -- but not a true one
	foreach ( keys %$varsref )
	{
		my $value = $$varsref{$_};
		delete $$varsref{$_} unless ( defined($value) && $value ne "" );
	}

	# Store the changed hash for calls to getVars
	$$this{$store} = $varsref;

	my $str = join(
		"&",
		map( $_ . "=" . Everything::Util::escape( $$varsref{$_} ),
			keys %$varsref )
	);

	# Put the serialized hash into the field var
	$$this{$field} = $str;

	return;
}

=cut


=head2 C<getNodeDatabaseHash>

This will retrieve a hash of this node, but with only the keys that exist in
the database.  We store a lot of extra info on the node and its sometimes
needed to get just the keys that exist in the database.

Returns hashref of the node with only the keys that exist in the database

=cut

sub getNodeDatabaseHash
{

        Everything->deprecate;
	my ($this) = @_;
	my $tableArray;
	my @fields;
	my %keys;

	$tableArray = $this->type->getTableArray(1);
	foreach my $table (@$tableArray)
	{

		# Get the fields for the table.
		@fields = $$this{DB}->getFields($table);

		# And add only those fields to the hash.
		@keys{@fields} = @$this{@fields};
	}

	return \%keys;
}

=cut


=head2 C<isNodetype>

Quickie function to see if a node is a nodetype.  This basically abstracts out
the isOfType(1) call.  In case nodetype is not id 1 in the future, we can
easily change this.

Returns true if this node is a nodetype, false otherwise.

=cut

sub isNodetype
{
	my ($this) = @_;
        Everything->deprecate;
	return $this->isOfType(1);
}

=cut


=head2 C<getParentLocation>

Get the parent location of this node.

=cut

sub getParentLocation
{
	my ($this) = @_;
        Everything->deprecate;
	return $$this{DB}->getNode( $$this{loc_location} );
}

=cut



=head2 C<existingNodeMatches>

Mainly used for importing purposes to see of a node matching this one already
exists in the database.  It doesn't make much sense to call this on a node that
already exists.  Its pretty much used for "dummy" nodes that do not exist in
the database yet.

Returns the node in the database if one exists that matches this one (matching
is based on the getIdentifyingFields() method) undef if no match was found.

=cut

# XXXXXXXXXXXXXXX To be deprecated should be a nodebase method

sub existingNodeMatches
{
	my ($this, $nodebase ) = @_;

	# if this already exists in the database, just return it...
	# It should be noted that if you are hitting this case, you are
	# probably doing something weird as it doesn't make sense to
	# be calling this on a node that already exists in the database.
	return $this if ( $$this{node_id} > 0 );

	my @ID = ( "title", "type_nodetype" );
	my $fields = $this->getIdentifyingFields();
	push @ID, @$fields if ($fields);

	my %WHERE;

	@WHERE{@ID} = @$this{@ID};
	my $NODE = $nodebase->getNode( \%WHERE, $this->type );

	return $NODE;
}

sub get_nodebase {
    $_[0]->{DB};
}

sub type {
 my $self = shift;
 return $self->_type;
}

sub type_title {
    my $self = shift;

     blessed( $self ) =~ /::(\w+)$/;

    return $1;

}

#############################################################################
# End of package
#############################################################################

1;
