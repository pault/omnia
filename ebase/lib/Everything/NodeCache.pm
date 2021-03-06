
=head1 C<Everything::NodeCache>

Copyright 2003, Everything Development Company.

A module for creating and maintaining a persistant cache of nodes The cache can
have a size limit and only caches nodes of specific types.

Each httpd runs in its own fork and memory space so we cannot share the cache
info across httpd's (even if we could, it wouldn't work for multiple web server
machines).  So each httpd keeps a cache for itself.  A problem arises when one
httpd process modifies a node that another process has in its cache.  How does
that other httpd process know that what it has in its cache is stale?

Well, we keep a "temporary" db table named 'version' (its temporary in the
sense that its only needed for caching and if you drop it, we just create a new
one).  Each time a node is updated in the db, we increment the version number
in the 'version' table.  When a node is retrieved from the cache, we compare
the cached version to the global version in the db table.  If they are the
same, we know that the node has not changed since we cached it.  If it is
different, we know that the cached node is stale.

Theoretical performance of this cache is O(log n) where n is the number of
versions in the 'version' table.  Perl hash lookups are O(1) (what we do to
find the node), and db table lookups for primary keys are O(log n) (what we do
to verify that the node is not stale).  So we have a O(1) + O(log n) = O(log
n).

A possible issue that we might need to deal with in the future, is the fact
that entries to the version table do not get removed.  So potentially, the
version table could grow to be the number of nodes in the system.  A way to
temporarily fix this problem right now would be to delete rows from the version
table where the version is less than a certain value (say 50), that would
remove all of the little used nodes from the version table.

=cut

package Everything::NodeCache;

use strict;
use Everything::CacheQueue;
use Scalar::Util qw/blessed/;

=cut


=head2 C<new>

Constructor for this "object".

=over 4

=item * $nodeBase

the Everything::NodeBase that we should use for database access.

=item * $maxSize

the maximum number of nodes that this cache should hold.  -1 if unlimited.  If
you have a large everything implementation, setting this to -1 would be bad.

=back

Returns the newly constructed module object

=cut

sub new
{
	my ( $packageName, $nodeBase, $maxSize ) = @_;
	my $this = {};

	bless $this, $packageName;    # oh, my lord

	$this->{maxSize}  = $maxSize;
	$this->{nodeBase} = $nodeBase;

	$this->{nodeQueue} = new Everything::CacheQueue();

	# We will keep different hashes for ids and name/type combos
	$this->{typeCache}    = {};
	$this->{groupCache}   = {};
	$this->{idCache}      = {};
	$this->{version}      = {};
	$this->{verified}     = {};
	$this->{typeVerified} = {};
	$this->{typeVersion}  = {};

	$this->{methodCache} = {};

	return $this;
}

=cut


=head2 C<setCacheSize>

Change the max size of the cache.  If the size is set lower than the current
number of nodes in the cache, the least used nodes will be removed to get the
cache size down to the new max.

=over 4

=item * $newMaxSize

the new size of the cache.

=back

=cut

sub setCacheSize
{
	my ( $this, $newMaxSize ) = @_;

	$this->{maxSize} = $newMaxSize;
	$this->purgeCache();
}

=cut


=head2 C<getCacheSize>

Returns the number of nodes in the cache (the size).

=cut

sub getCacheSize
{
	my ($this) = @_;
	my $size;

	$size = $this->{nodeQueue}->getSize();

	return $size;
}

=cut


=head2 C<getCachedNodeByName>

Query the cache to see if it has the node of the given title and type.  The
type is required, otherwise we would need to return lists, and lists from a
cache are most likely not going to be complete.

=over 4

=item * $title

the string title of the node we are looking for

=item * $typename

the nodetype name (ie 'node') of the type that we are looking for

=back

Returns a $NODE hashref if we have it in the cache, otherwise undef.

=cut

sub getCachedNodeByName
{
	my ( $this, $title, $typename ) = @_;
	my $hashkey;
	my $data;
	my $NODE;

	return if ( not defined $typename );

	if ( defined $this->{typeCache}{$typename}{$title} )
	{
		$data = $this->{typeCache}{$typename}{$title};
		$NODE = $this->{nodeQueue}->getItem($data);

		if ( $$NODE{title} ne $title )
		{
			delete $this->{typeCache}{$typename}{$title};
			return;
		}
		return $NODE if ( $this->isSameVersion($NODE) );
	}

	return;
}

=cut


=head2 C<getCachedNodeById>

Query the cache for a node with the given id

=over 4

=item * $id

the id of the node we are looking for

=back

Returns a node hashref if we find anything, otherwise undef

=cut

sub getCachedNodeById
{
	my ( $this, $id ) = @_;
	my $data;
	my $NODE;

	if ( defined $this->{idCache}{$id} )
	{
		$data = $this->{idCache}{$id};
		$NODE = $this->{nodeQueue}->getItem($data);

		return $NODE if ( $this->isSameVersion($NODE) );
	}

	return;
}

=cut


=head2 C<cacheNode>

Given a node, put it in the cache

=over 4

=item * $NODE

the node hashref to put in the cache

=item * $permanent

True if this node is to never be removed from the cache when purging.

=back

=cut

sub cacheNode
{
	my ( $this, $NODE, $permanent ) = @_;
	my ( $type, $title ) = ( $NODE->type_title, $NODE->get_title );
	my $data;

	if ( defined( $this->{idCache}{ $$NODE{node_id} } ) )
	{

		# This node is already in the cache, lets remove it (this will get
		# rid of the old stale data) and reinsert it into the cache.
		$this->removeNode($NODE);

		# If we are removing a node that already existed, it is because it
		# has been updated.  We need to increment the global version.
		#$this->incrementGlobalVersion($NODE)
	}

	# Add the NODE to the queue.  This puts the newly cached node at the
	# end of the queue.
	$data = $this->{nodeQueue}->queueItem( $NODE, $permanent );

	# Store hash keys for its "name" and numeric Id, and set the version.
	$this->{typeCache}{$type}{$title}   = $data;
	$this->{idCache}{ $$NODE{node_id} } = $data;
	$this->{version}{ $$NODE{node_id} } = $this->getGlobalVersion($NODE);

	$this->purgeCache();

	return 1;
}

=cut


=head2 C<removeNode>

Remove a node from the cache.  Usually needed when a node is deleted.

=over 4

=item * $NODE

the node in which to remove from the cache

=back

Returns the NODE removed from the cache, undef if the node was not in the
cache.

=cut

sub removeNode
{
	my ( $this, $NODE ) = @_;
	my $data = $this->removeNodeFromHash($NODE);

	# temporary keys are marked with a leading underscore
	# this gets rid of cached subs, for example
	my @tempkeys = grep( /^_/, keys %$NODE );
	delete @$NODE{@tempkeys};

	# Removing a node for any reason from the cache warrants a version
	# increment.  Usually when a node is removed from the cache, it is
	# being deleted.
	# nate sez -- I think the IGV call in cacheNode takes care of this
	#$this->incrementGlobalVersion($NODE);

	return $this->{nodeQueue}->removeItem($data);
}

=cut


=head2 C<flushCache>

Remove all nodes from this cache.  Since each httpd process is in its own
separate memory space, this will only flush the cache for this particular httpd
process.

=cut

sub flushCache
{
	my ($this) = @_;

	# Delete all the stuff that we were hanging on to.
	undef $this->{nodeQueue};
	undef $this->{typeCache};
	undef $this->{idCache};
	undef $this->{version};
	undef $this->{groupCache};

	$this->{nodeQueue}  = new Everything::CacheQueue();
	$this->{typeCache}  = {};
	$this->{idCache}    = {};
	$this->{version}    = {};
	$this->{groupCache} = {};
}

=cut


=head2 C<flushCacheGlobal>

This flushes the global cache by incrementing the entire global version table.
In doing so, the version of the nodes that the various httpd's have cached will
no longer match the global verison, which will cause nodes to get thrown out
when they go to get used.  This will probably only be needed for debugging
(since 'kill -HUP' on the web server will clear the caches anyway), or when a
cache flush is needed for nodetypes.

=cut

sub flushCacheGlobal
{
	my ($this) = @_;

	$this->flushCache();
	$this->{nodeBase}->sqlUpdate( "version", { -version => "version+1" } );
}

=cut


=head2 C<dumpCache>

Get a dump of all the nodes that are in the cache (primarily useful for
debugging or system stats)

Returns a reference to an array that contains all of the nodes in the cache.
Useful for debugging.

=cut

sub dumpCache
{
	my ($this) = @_;
	my $queue = $this->{nodeQueue}->listItems();

	return $queue;
}

#############################################################################
# "Private" module subroutines - users of this module should never call these
#############################################################################

=cut


C<purgeCache>

Remove nodes from cache until the size is under the max size.  The nodes
removed are the least used nodes in the cache.

=cut

sub purgeCache
{
	my ($this) = @_;

	# We can't have the number of permanent items in the cache be the
	# same or greater than the maxSize.  This would cause an infinite
	# loop here.  So, if we determine that the number of permanent items
	# is greater than or equal to our max size, we will double the cache
	# size.  In general practice, the number of permanent nodes should
	# be small.  So, this is only for cases where the cache size is set
	# unusually small.
	if ( $this->{nodeQueue}->{numPermanent} >= $this->{maxSize} )
	{
		$this->setCacheSize( $this->{maxSize} * 2 );
	}

	while (( $this->{maxSize} > 0 )
		&& ( $this->{maxSize} < $this->getCacheSize() ) )
	{

		# We need to remove the least used node from our cache to keep
		# the cache size under the maximum.
		my $leastUsed = $this->{nodeQueue}->getNextItem();

		$this->removeNodeFromHash($leastUsed);
	}

	return 1;
}

=cut


C<removeNodeFromHash>

Remove a node from the cache hash.

=over 4

=item * $NODE

the node to remove.

=back

Returns the node data, if it was removed.  Undef otherwise.

=cut

sub removeNodeFromHash
{
	my ( $this, $NODE )  = @_;
	my ( $type, $title ) = ( $NODE->type_title, $NODE->get_title );

	if ( defined $this->{idCache}{ $$NODE{node_id} } )
	{
		my $data = $this->{typeCache}{$type}{$title};

		# Remove this hash entry
		delete( $this->{typeCache}{$type}{$title} );
		delete( $this->{idCache}{ $$NODE{node_id} } );
		delete( $this->{version}{ $$NODE{node_id} } );
		delete $this->{groupCache}{ $$NODE{node_id} };

		return $data;
	}

	return;
}

=cut


C<getGlobalVersion>

Get the version number of this node from the global version db table.

=over 4

=item * $NODE

the node for which we want the version number.

=back

Returns the version number -- will be 1 if this added it to the table.

=cut

sub getGlobalVersion
{
	my ( $this, $NODE ) = @_;

	my $ver =
		$this->{nodeBase}
		->sqlSelect( "version", "version", "version_id=" . $NODE->get_node_id );

	if ( ( not defined $ver ) || ( not $ver ) )
	{

		# The version for this node does not exist.  We need to start it off.
		$this->{nodeBase}->sqlInsert( 'version',
			{ version_id => $$NODE{node_id}, version => 1 } );

		$ver = 1;
	}

	return $ver;
}

=cut


=head2 C<isSameVersion>

Check to see that this node has the same version number as the other httpd
processes (that is, check the version db table).

=over 4

=item * $NODE

the node in question.

=back

Returns 1 if the version is the same, 0 if not.

=cut

sub isSameVersion
{
	my ( $this, $NODE ) = @_;
	return unless defined $NODE;

	return 1 if exists $this->{typeVerified}{ $NODE->get_type_nodetype };
	return 1 if exists $this->{verified}{ $NODE->{node_id} };
	return 0 unless exists $this->{version}{ $NODE->{node_id} };

	my $ver = $this->getGlobalVersion($NODE);

	if ( defined $ver && $ver == $this->{version}{ $NODE->{node_id} } )
	{
		$this->{verified}{ $NODE->{node_id} } = 1;
		return 1;
	}

	return 0;
}

=cut


C<incrementGlobalVersion>

This increments the version associated with the given node in the db table.
This is used to let the other processes know that a node has changed (different
version).

=over 4

=item * $NODE

the node in which to increment the version for.

=back

=cut

sub incrementGlobalVersion
{
	my ( $this, $NODE ) = @_;
	my %version;
	my $rowsAffected;

	$rowsAffected =
		$this->{nodeBase}->sqlUpdate( 'version', { -version => 'version+1' },
		"version_id=$$NODE{node_id}" );

	if ( $rowsAffected == 0 )
	{

		# The version for this node does not exist.  We need to start it off.
		$this->{nodeBase}->sqlInsert( 'version',
			{ version_id => $$NODE{node_id}, version => 1 } );
	}
	$this->{nodeBase}->sqlUpdate(
		'typeversion',
		{ -version => 'version+1' },
		"typeversion_id=" . $NODE->get_type_nodetype
		)
		if $this->{nodeBase}->sqlSelect( "version", "typeversion",
		"typeversion_id=" . $NODE->get_type_nodetype );
}

=cut


C<resetCache>

We only want to check the version a maximum of once per page load.  The
"verified" hash keeps track of what nodes we have checked the version of so
far.  This should be called for each page load to clear this hash out.

This also handles typeVersions -- the table must be rebuilt each pageload, if 

=cut

sub resetCache
{
	my ($this) = @_;

	$this->{verified}     = {};
	$this->{typeVerified} = {};
	my %newVersion;
	my @confirmTypes;

	if ( my $csr = $this->{nodeBase}->sqlSelectMany( '*', "typeversion" ) )
	{
		while ( my $N = $csr->fetchrow_hashref )
		{
			if ( exists $this->{typeVersion}{ $$N{typeversion_id} } )
			{
				if ( $this->{typeVersion}{ $$N{typeversion_id} } ==
					$$N{version} )
				{
					$this->{typeVerified}{ $$N{typeversion_id} } = 1;
				}
				else
				{
					push @confirmTypes, $$N{typeversion_id};
				}
			}
			else
			{
				push @confirmTypes, $$N{typeversion_id};
			}

			#if the typeversion haven't changed, we can verify the type
			$newVersion{ $$N{typeversion_id} } = $$N{version};
		}
		$csr->finish;
	}

	#nodemethods MUST be typeversioned
	my $nodemethod_id =
		$this->{nodeBase}->sqlSelect( 'node_id', 'node', "title='nodemethod'" );
	if ( $nodemethod_id and not $this->{typeVersion}{$nodemethod_id} )
	{
		unless ( exists( $newVersion{$nodemethod_id} ) )
		{
			$this->{nodeBase}->sqlInsert(
				'typeversion',
				{
					typeversion_id => $nodemethod_id,
					version        => 1
				}
			);
		}
		$this->{typeVersion}{$nodemethod_id} = 1;
	}

	#some types that are typeVersion have changed, or have just been added
	#to typeversion.  we need to remove any stale data from that type
	foreach my $nodetype_id (@confirmTypes)
	{
		my $typename =
			$this->{nodeBase}
			->sqlSelect( "title", 'node', "node_id=$nodetype_id" );
		foreach my $nodename ( keys %{ $this->{typeCache}{$typename} } )
		{
			my $NODE =
				$this->{nodeQueue}
				->getItem( $this->{typeCache}{$typename}{$nodename} );
			if ( not $this->isSameVersion($NODE) )
			{
				$this->removeNode($NODE);
			}

		}
		$this->{typeVerified}{$nodetype_id} = 1;
		$this->{methodCache} = {} if $typename eq 'nodemethod';
	}

	$this->{typeVersion} = \%newVersion;

	#replace the typeVersion with the most recent table

	"";
}

=cut


C<cacheMethod>

We like being able to compile embedded code sections and cache them to save
parsing/compiling time on future page displays.  This fiddles with the
internals of the cache queue to associate anonymous sub refs with the
associated node.  It's not completely beautiful, but it works with the present
caching system.

=over 4

=item * $NODE

the node object containing the embedded code

=item * $field

the field of $NODE directly containing the embedded code

=item * $sub_ref

a reference to the compiled sub

=back

Returns 1 on success, 0 on failure ($NODE probably isn't cached)

=cut

sub cacheMethod
{
	my ( $this, $NODE, $field, $sub_ref ) = @_;
	my ( $type, $title ) = ( $NODE->type_title, $NODE->get_title );
	my $data = $this->{typeCache}{$type}{$title};
	if ( defined( $data->{item} ) )
	{
		$data->{item}{"_cached_$field"} = $sub_ref;
		return 1;
	}
	return 0;
}

#############################################################################
# End of package Everything::NodeCache
#############################################################################

1;
