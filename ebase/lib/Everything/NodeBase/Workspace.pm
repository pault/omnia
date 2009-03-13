=head1 Everything::NodeBase::Workspace

Wrapper for the Everything database and cache with workspace ability.

Copyright 2006 Everything Development Inc.

=cut

package Everything::NodeBase::Workspace;

use strict;
use warnings;

use base 'Everything::NodeBase';

=head2 C<joinWorkspace>

create the $DB-E<gt>{workspace} object if a workspace is specified.  If the
sole parameter is 0, then the workspace is deleted.

=over 4

=item * WORKSPACE

workspace_id, node, or 0 for none

=back

=cut

sub joinWorkspace
{
	my ( $this, $WORKSPACE ) = @_;
	return 1 unless $WORKSPACE;

	$this->getRef($WORKSPACE);
	return -1 unless $WORKSPACE;

	$this->{workspace}                 = $WORKSPACE;
	$this->{workspace}{nodes}          = $WORKSPACE->getVars();
	$this->{workspace}{nodes}        ||= {};
	$this->{workspace}{cached_nodes}   = {};

	1;
}

=head2 C<getNodeWorkspace>

Helper function for getNode's workspace functionality.  Given a $WHERE hash
(field =E<gt> value, or field =E<gt> [value1, value2, value3]) return a list of
nodes in the workspace which fulfill this query.

=over 4

=item * $WHERE

where hash, similar to getNodeWhere

=item * $TYPE

type discrimination (optional)

=back

=cut

sub getNodeWorkspace
{
	my ( $this, $WHERE, $TYPE ) = @_;
	my @results;
	$TYPE = $this->getType($TYPE) if $TYPE;

	# compare node ids
	my $cmpval = sub
	{
		my ( $val1, $val2 ) = @_;

		$val1 = $val1->{node_id} if eval { $val1->isa( 'Everything::Node' ) };
		$val2 = $val2->{node_id} if eval { $val2->isa( 'Everything::Node' ) };

		$val1 eq $val2;
	};

	# iterate through the workspace
	for my $node ( keys %{ $this->{workspace}{nodes} } )
	{
		my $N = $this->getNode($node);
		next if $TYPE and $N->get_type_nodetype != $TYPE->getId;

		my $match = 1;

		for my $where ( keys %$WHERE )
		{
			if ( ref $WHERE->{$where} eq 'ARRAY' )
			{
				$match = 0;

				for my $orval ( @{ $WHERE->{$where} } )
				{
					next unless $cmpval->( $N->{$where}, $orval );
					$match = 1; 
					last;
				}
			}
			else
			{
				$match = 0 unless $cmpval->( $N->{$where}, $WHERE->{$where} );
			}
		}
		push @results, $N if $match;
	}

	return \@results;
}

=head2 C<getNode>

This overrides C<getNode()> to allow for workspaced fetches.

=over 4

=item * $node

either the string title, node id, NODE object, or "where hash ref".  The NODE
object is just for ease of use, so you can call this function without worrying
if the node thingy is an ID or object.  If this is a where hash ref, this
simply does a getNodeWhere() and returns the first match only (just a quicky
way of doing a getNodeWhere())

=item * $ext

extra info.  If $node is a string title, this must be either a hashref to a
nodetype node, or a nodetype id.  If $node is an id, $ext is optional and can
be either 'light' or 'force'.  If 'light' it will retrieve only the information
from the node table (faster).  If 'force', it will reload the node even if it
is cached.

=item * $ext2

more extra info.  If this is a "title/type" query, passing 'create' will cause
a dummy object to be created and returned if a node is not found.  Using the
dummy node, you can then add or modify its fields and then do a
$NODE-E<gt>insert($USER) to insert it into the database.  If you wish to create
a node even if a node of the same "title/type" exists, pass "create force".  A
dummy node has a node_id of '-1'.

If $node is a "where hash ref", this is the "order by" string that you can pass
to order the result by (you will still only get one node).

=back

Returns a node object if successful.  undef otherwise.

=cut

sub getNode
{
	my ( $this, $node, $ext, $ext2 ) = @_;
	return unless defined $node and $node ne '';

	# it may already be a node
	return $node if eval { $node->isa( 'Everything::Node' ) };

	my $cache = "";

	if ( ref $node eq 'HASH' )
	{
		# This a "where" select
		my $nodeArray   = $this->getNodeWhere( $node, $ext, $ext2, 1 ) || [];
		my $wspaceArray = $this->getNodeWorkspace( $node, $ext );

		# the nodes we get back are unordered, must be merged with the
		# workspace.  Also any nodes which were in the nodearray, and the
		# workspace, but not the wspace array must be removed

		my @results = (
			( grep { !exists $this->{workspace}{nodes}{ $_->{node_id} } }
				@$nodeArray ),
			@$wspaceArray
		);

		return unless @results;
		my $orderby  = $ext2 || 'node_id';
		my $position = ( $orderby =~ s/\s+desc//i ) ? -1 : 0;
		@results     = sort { $a->{$orderby} cmp $b->{$orderby} } @results;
		return $results[$position];
	}

	my $NODE = $this->SUPER( $node, $ext, $ext2 );
	return unless $NODE;

	if (exists $this->{workspace}{nodes}{ $NODE->{node_id} }
		   and $this->{workspace}{nodes}{ $NODE->{node_id} } )
	{
		my $WS = $NODE->getWorkspaced();
		return $WS if $WS;
	}

	return $NODE;
}

1;
