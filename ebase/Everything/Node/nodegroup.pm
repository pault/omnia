package Everything::Node::nodegroup;

#############################################################################
#   Everything::Node::nodegroup
#       Package the implements the base nodegroup functionality
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;


#############################################################################
sub construct
{
	my ($this) = @_;
	my $groupTable = $$this{type}{derived_grouptable};
	my $nid;
	
	# construct our array of node id's of the nodes in our group
	my $cursor = $$this{DB}->sqlSelectMany('node_id', $groupTable,
		$groupTable . "_id=$$this{node_id}", 'ORDER BY orderby');

	while($nid = $cursor->fetchrow)
	{
		push @{ $$this{group} }, $nid;
	}
	$cursor->finish();

	# We could call selectNodegroupFlat() here to have that info ready.
	# However, since that info may not be needed all the time, we will
	# save the CPU time and memory space and not call it.  If you need
	# to have the entire group, call selectNodegroupFlat() at that time.
}


#############################################################################
sub destruct
{
	my ($this) = @_;

	$this->SUPER();

	delete $$this{group};
	delete $$this{flatgroup};
}


#############################################################################
#	Sub
#		nuke
#
#	Purpose
#		Nodegroups have entries in their group table that we need to
#		clean up before this node goes away.  This will delete all
#		nodegroup entries from that table, then call SUPER to delete
#		the node
#
sub nuke
{
	my ($this, $USER) = @_;	
	my $sql;
	my $table = $this->isGroup();

	$$this{DB}->getRef($USER);
	return 0 unless($this->hasAccess($USER, 'd'));

	$sql = "delete from " . $table . " where " . $table .
		"_id=$$this{node_id}";

	# Delete them group entries
	$$this{DB}->{dbh}->do($sql);

	# Now go delete the node!
	$this->SUPER();
}


#############################################################################
sub isGroup
{
	my ($this) = @_;
	return $$this{type}{derived_grouptable};
}


#############################################################################
#	Sub
#		inGroupFast
#
#	Purpose
#		This just does a brute force check (which happens to be the fastest)
#		to see if a particular node is in a group.
#
#	NOTE!!!
#		This only works for groups that do NOT contain sub groups.  If the
#		group contains sub groups, you will need to use inGroup()
#
#	Parameters
#		NODE - the node id or node hash of the node that we wish to check for
#			group membership
#
#	Returns
#		1 (true) if the given node is in the group.  0 (false) otherwise.
#
sub inGroupFast
{
	my ($this, $NODE) = @_;
	my $table = $$this{type}{derived_grouptable};
	my $groupId = $this->getId();
	my $nodeId = $$this{DB}->getId($NODE);
	my $match = $$this{DB}->sqlSelect("node_id", $table,
		$table . "_id=$groupId && node_id=$nodeId" );

	# Note this does not handle sub groups.  If the group contains
	# sub groups you will need to use inGroup
	return 1 if($match);
	return 0;
}


#############################################################################
#	Sub
#		inGroup
#
#	Purpose
#		This checks to see if the given node belongs to the given group.
#		This will check all sub groups.  If you know for a fact that your
#		group does not contain sub groups, you will probably want to call
#		inGroupFast() instead as it will be significantly faster in most
#		cases.
#
#	Parameters
#		NODE - the node id or node hash of the node that we wish to check for
#			group membership
#
#	Returns
#		1 (true) if the given node is in the group.  0 (false) otherwise.
#
sub inGroup
{
	my ($this, $NODE) = @_;
	my $members;
	my $id = $$this{DB}->getId($NODE);

	return 0 if(not defined $NODE);

	$members = $this->selectNodegroupFlat();
	foreach my $member (@$members)
	{
		return 1 if($$this{DB}->getId($member) == $id);
	}

	return 0;
}


#############################################################################
#	Sub
#		selectNodegroupFlat
#
#	Purpose
#		This recurses through the nodes and node groups that this group
#		contains getting the node hash for each one on the way.
#
#	Parameters
#		$NODE - the group node to get node hashes for.
#
#	Returns
#		An array of node hashes that belong to this group.
#
sub selectNodegroupFlat
{
	my ($this, $groupsTraversed) = @_;
	my @listref;
	my $group;

	# If we have already calculated this group, return it.
	return $$this{flatgroup} if(exists $$this{flatgroup});

	# If groupsTraversed is not defined, initialize it to an empty
	# hash reference.
	$groupsTraversed ||= {};  # anonymous empty hash

	# return if we have already been through this group.  Otherwise,
	# we will get stuck in infinite recursion.
	return undef if(exists $$groupsTraversed{$$this{node_id}});
	$$groupsTraversed{$$this{node_id}} = $$this{node_id};
	
	foreach my $groupref (@{ $$this{group} })
	{
		my $NODE = $$this{DB}->getNode($groupref);
		
		if($NODE->isGroup())
		{
			$group = $NODE->selectNodegroupFlat($groupsTraversed);
			push(@listref, @$group) if(defined $group);
		}
		else
		{
			push @listref, $NODE;
		}
	}
	
	$$this{flatgroup} = \@listref;
	
	return $$this{flatgroup};
}


#############################################################################
#	Sub
#		insertIntoGroup
#
#	Purpose
#		This will insert a node(s) into a nodegroup.
#
#		NOTE!  It appears that inserting into a nodegroup does not
#		update the node itself (the node is added to the group, but
#		the group node is left untouched).  This prevents other httpd
#		processes from knowing that the group has been updated, which
#		means they will probably have stale group info.
#
#	Parameters
#		USER - the user trying to add to the group (used for authorization)
#		insert - the node or array of nodes to insert into the group
#		orderby - the criteria of which to order the nodes in the group
#
#	Returns
#		The group NODE hash that has been refreshed after the insert.
#		undef if the user does not have permissions to change this group.
#
sub insertIntoGroup
{
	my ($this, $USER, $insert, $orderby) = @_;
	my $groupTable = $$this{type}{derived_grouptable};
	my $insertref;
	my $rank;	

	return undef unless($this->hasAccess($USER, "w")); 
	
	if(ref ($insert) eq "ARRAY")
	{
		$insertref = $insert;

		# If we have an array, the order is specified by the order of
		# the elements in the array.
		undef $orderby;
	}
	else
	{
		# converts to a list reference w/ 1 element if we get a scalar
		$insertref = [$insert];
	}
	
	foreach my $INSERT (@$insertref)
	{
		$$this{DB}->getRef($INSERT);
		my $maxOrderBy;
		
		# This will return a value if the select is not empty.  If
		# it is empty (there is nothing in the group) it will be null.
		$maxOrderBy = $$this{DB}->sqlSelect('MAX(orderby)', $groupTable, 
			$groupTable . "_id=$$this{node_id}"); 

		if (defined $maxOrderBy)
		{
			# The group is not empty.  We may need to change some ordering
			# information.
			if ((defined $orderby) && ($orderby <= $maxOrderBy))
			{ 
				# The caller of this function specified an order position
				# for the new node in the group.  We need to make a spot
				# for it.  To do this, we will increment each orderby
				# field that is the same or higher than the orderby given.
				# If orderby is greater than the current max orderby, we
				# don't need to do this.
				$$this{DB}->sqlUpdate($groupTable,
					{ '-orderby' => 'orderby+1' }, 
					$groupTable. "_id=$$this{node_id} && orderby>=$orderby");
			}
			elsif(not defined $orderby)
			{
				$orderby = $maxOrderBy+1;
			}
		}
		elsif(not defined $orderby)
		{
			$orderby = 0;  # start it off
		}
		
		$rank = $$this{DB}->sqlSelect('MAX(rank)', $groupTable, 
			$groupTable . "_id=$$this{node_id}");

		# If rank exists, increment it.  Otherwise, start it off at zero.
		$rank = ((defined $rank) ? $rank+1 : 0);

		$$this{DB}->sqlInsert($groupTable,
			{ $groupTable . "_id" => $$this{node_id}, 
			rank => $rank, node_id => $$INSERT{node_id},
			orderby => $orderby});

		# if we have more than one, we need to clear this so the other
		# inserts work.
		undef $orderby;
	}
	
	# we should also refresh the group list ref stuff
	$_[0] = $$this{DB}->getNode($$this{node_id}, 'force'); #refresh the group
}


#############################################################################
#	Sub
#		removeFromGroup
#
#	Purpose
#		Remove a node from a group.
#
#	Parameters
#		$NODE - the node to remove
#		$USER - the user who is trying to do this (used for authorization)
#
#	Returns
#		The newly refreshed nodegroup hash.  If you had called
#		selectNodegroupFlat on this before, you will need to do it again
#		as all data will have been blown away by the forced refresh.
#
sub removeFromGroup 
{
	my ($this, $NODE, $USER) = @_;
	my $groupTable = $$this{type}{derived_grouptable}; 
	my $success;
	my $node_id;
	
	$this->hasAccess($USER, "w") or return; 

	$node_id = $$this{DB}->getId($NODE);
	$success = $$this{DB}->sqlDelete ($groupTable,
		$groupTable . "_id=$$this{node_id} && node_id=$node_id");

	if($success)
	{
		# If the delete did something, we need to refresh this group node.	
		# We assign it to $_[0] so that the object that the caller is
		# holding onto will be transparently updated for them.
		$_[0] = $this->getNode($$this{node_id}, 'force');
	}

	return $_[0];
}


#############################################################################
#	Sub
#		replaceGroup
#
#	Purpose
#		This removes all nodes from the group and inserts new nodes.
#
#	Parameters
#		$REPLACE - A node or array of nodes to be inserted
#		$USER - the user trying to do this (used for authorization).
#
#	Returns
#		The group NODE hash that has been refreshed after the insert
#
sub replaceGroup
{
	my ($this, $REPLACE, $USER) = @_;
	my $groupTable = $$this{type}{derived_grouptable};

	$this->hasAccess($USER, "w") or return; 

	$$this{DB}->sqlDelete($groupTable, $groupTable . "_id=$$this{node_id}");
	return $_[0]->insertIntoGroup($USER, $REPLACE);  
}


#############################################################################
#	Sub
#		getNodeKeys
#
sub getNodeKeys
{
	my ($this, $forExport) = @_;
	my $keys = $this->SUPER();
	
	if($forExport)
	{
		# Groups are special.  There is one field that we do want to
		# include for export... the group field that is generated
		# when the group node is constructed.
		$$keys{group} = $$this{group};
	}

	return $keys;
}


#############################################################################
#	Sub
#		getFieldDatatype
#
#	Purpose
#		Groups have one special field type, groups (surprise!).  We
#		need to return the correct datatype for that field.
#
sub getFieldDatatype
{
	my ($this, $field) = @_;

	return "group" if($field eq "group");
	return $this->SUPER();
}


#############################################################################
# End of package
#############################################################################

1;
