package Everything::Node::location;

#############################################################################
#   Everything::Node::location
#       Package the implements the base functionality for locations
#
#   Copyright 2000 - 2002 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;


#############################################################################
#	Sub
#		nuke
#
#	Purpose
#		Overrides the base node::nuke so we can move all the nodes that
#		exist in this location to the parent location.
#
sub nuke
{
	my ($this, $USER) = @_;
	my $id = $$this{node_id};
	my $parentLoc = $$this{loc_location};
	my $result = $this->SUPER();
	
	if($result > 0)
	{
		# Set all the nodes that were in this location to be in the
		# parent location... deleting a location does not delete all
		# the nodes inside of it.
		$$this{DB}->sqlUpdate("node", { loc_location => $parentLoc },
			"loc_location=$id");
	}

	return $result;
}


=cut

=head2 C<listNodes>

=head3 Purpose
	
Get a list of all the nodes in this location, just like an 'ls'.  The nodes are
ordered by title.

=head3 Parameters

=over 4

=item * $full

(optional) set to true if you want a list of node objects.  if false/undef, the
list will contain only node id's.

=back

=head3 Returns

An array ref to an array that contains the nodes.

=cut
sub listNodes
{
	my ($this, $full) = @_;

	return $this->listNodesWhere('', '', $full);
}

=cut

=head2 C<listNodesWhere>

=head3 Purpose
	
Get a list of all the nodes in this location, similar to doing an 'ls' with
options.  The results can be resricted and ordered as desired.

=head3 Parameters

=over 4

=item * $where

(optional) a where clause.  Note that the location will already be restricted
automatically.

=item * $order

(optional) an order clause.  This defaults to ordering results by their title.

=item * $full

(optional) set to true if you want a list of node objects.  if false/undef, the
list will contain only node id's.

=back

=head3 Returns

An array ref to an array that contains the nodes.

=cut
sub listNodesWhere
{
	my ($this, $where, $order, $full) = @_;
	$where ||= '';
	$order ||= "order by title";
	$where  .= " loc_location='$$this{node_id}'";

	my @nodes;

	if (my $csr = $$this{DB}->sqlSelectMany("node_id", "node", $where, $order))
	{
		while(my $id = $csr->fetchrow())
		{
			$$this{DB}->getRef($id) if($full);
			push @nodes, $id;
		}

		$csr->finish(); 
	}
	
	return \@nodes;
}

#############################################################################
# End of package
#############################################################################

1;
