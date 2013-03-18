package Everything::NodeBase::Cached;

use strict;
use warnings;

use Everything::NodeCache;

use Moose;
use MooseX::FollowPBP; 


extends 'Everything::NodeBase';

our %cache;

sub BUILD {

        my $this = shift;

	if ( ! $cache{ $this->get_dbname } ) {
	    $cache{ $this->get_dbname } = Everything::NodeCache->new( $this, 300 );
	}

	$this->{cache}           = $cache{ $this->get_dbname };
	if ( $this->getType('setting') )
	{
		my $CACHE     = $this->getNode( 'cache settings', 'setting' );

		my $cacheSize = 300;

		# Get the settings from the system
		if ( defined $CACHE && $CACHE->isa( 'Everything::Node' ) )
		{
			my $vars = $CACHE->getVars();
			$cacheSize = $vars->{maxSize} if exists $vars->{maxSize};
		}

		$this->{cache}->setCacheSize($cacheSize);
	}

}

after update_workspaced_node => sub {

    my ($this, $node) = @_;

    # stops pollution of the cache
    $this->{cache}->removeNode($node);

};

override store_new_node => sub {

    my ($this, $node) = @_;

    my $result = super();

    return $result unless $result;

    # Cache this node since it has been inserted.  This way the cached
    # version will be the same as the node in the db.

    $this->{cache}->cacheNode( $node );

    return $result;
};

override update_stored_node => sub {

    my ($this, $node) = @_;

    return 0 unless super();

    # Cache this node since it has been updated.  This way the cached
    # version will be the same as the node in the db.

    $this->{cache}->incrementGlobalVersion($node);
    $this->{cache}->cacheNode( $node );
};

override delete_stored_node => sub {
    my ($this, $node, $USER) = @_;

    my $old_id = $node->{node_id};

    my $result = super();

    return $result unless $result;

    # Now we can remove the nuked node from the cache so we don't get
    # stale data.

    $node->{node_id} = $old_id;

    $this->{cache}->incrementGlobalVersion($node);
    $this->{cache}->removeNode($node);

    $node->{ node_id } = 0;

    return $result;

};

=head2 C<resetNodeCache>

The node cache holds onto nodes after they have been loaded from the database.
When a node is requested, it checks to see if it has the node in its cache.  If
it does, the cache will see if the version of the node is the same as what is
in the database.  This version check is done *once* to save hits to the
database.  If you want the cache to recheck the versions, call this function.

=cut

sub resetNodeCache
{
	my ($this) = @_;

	$this->{cache}->resetCache();
}

=head2 C<getCache>

This returns the NodeCache object that we are using to cache nodes.  In
general, you should never need to access the cache directly.  This is more for
maintenance type stuff (you want to check the cache size, etc).

Returns a reference to the NodeCache object

=cut

sub getCache
{
	my ($this) = @_;

	return $this->{cache};
}

# override getNode => sub {
#     my ( $self, $node, $ext, $ext2 )= @_;

#     # it may already be a node
#     return $node if eval { $node->isa( 'Everything::Node' ) };

#     $ext2 ||= q{};
#     my $cache = q{};

#     $cache = "nocache" if ( defined $ext && $ext eq 'light' );

#     $node = super();

#     return unless $node;

#     $cache ||= $node->get_nocache;
#     $self->{cache}->cacheNode( $node ) unless $cache;

#     return $node;
# };

override retrieve_node_using_name_type => sub {

    
    my ( $this, $name, $nodetype_title ) = @_;

    my $node;

    $node = $this->{cache}->getCachedNodeByName( $name, $nodetype_title );

    return $node if $node;

    $node = super();

    if ( $node ) {
	$this->{cache}->cacheNode( $node );
	return $node;
    }

    return;
};

override retrieve_node_using_id => sub {
    my ($self, $node, $ext) = @_;

    if ( ! $ext or $ext ne "force" )
      {
	  my $cached_node;
	  $cached_node = $node = $self->{cache}->getCachedNodeById($node);
	  return $cached_node if $cached_node;
      }

    my $retrieved_node = super;

    if ( $retrieved_node && ! ( $ext && $ext ne 'light' ) ) {
	$self->{cache}->cacheNode( $retrieved_node );
    }

    return $retrieved_node;

};

1;
