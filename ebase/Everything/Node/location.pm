package Everything::Node::location;

#############################################################################
#   Everything::Node::location
#       Package the implements the base functionality for locations
#
#   Copyright 2000 Everything Development Inc.
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


#############################################################################
#	Sub
#		listNodes
#
#	Purpose
#		Get a list of all the nodes in this location.  The result is
#		similar to doing an "ls".  The nodes are ordered by title.
#
#	Parameters
#		$full - (optional) set to true if you want a list of node objects.
#			if false/undef, the list will contain only node id's.
#
#	Returns
#		An array ref to an array that contains the nodes.
#
sub listNodes
{
	my ($this, $full) = @_;
	my $where = "loc_location=$$this{node_id}";
	my @nodes;

	my $csr = $$this{DB}->sqlSelectMany("node_id", "node", $where,
		"order by title");

	if($csr)
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
