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
use Everything::XML;
use XML::DOM;


#############################################################################
sub construct
{
	my ($this) = @_;

	my $group = $this->selectGroupArray();
	$$this{group} = $group;

	# We could call selectNodegroupFlat() here to have that info ready.
	# However, since that info may not be needed all the time, we will
	# save the CPU time and memory space and not call it.  If you need
	# to have the entire group, call selectNodegroupFlat() at that time.
}


#############################################################################
#	Sub
#		selectGroupArray
#
#	Purpose
#		Gets an array of node id's of the nodes the belong to this group.
#
#	Returns
#		An array ref of the node id's
#
sub selectGroupArray
{
	my ($this) = @_;
	my $groupTable = $this->isGroup();
	my $nid;
	my @group;
	
	# Make sure the table exists first
	$$this{DB}->createGroupTable($groupTable);

	# construct our array of node id's of the nodes in our group
	my $cursor = $$this{DB}->sqlSelectMany('node_id', $groupTable,
		$groupTable . "_id=$$this{node_id}", 'ORDER BY orderby');

	while($nid = $cursor->fetchrow)
	{
		push @group, $nid;
	}
	$cursor->finish();

	return \@group;
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
sub insert
{
	my ($this, $USER) = @_;

	return 0 unless($this->hasAccess($USER, 'c'));
	
	# We need to h4x0r this a bit.  node::insert clears the $this hash.
	# This clears all fields (including our group field).  Normally,
	# we would insert the group nodes first, but the problem is, this
	# node has not been inserted yet, so we don't have a node id to
	# insert them with.  So, we hold onto the group array for now.	
	my $group = $$this{group};
	my $return = $this->SUPER();

	# Now that the node has been inserted, we need to reassign our group
	# array.
	$$this{group} = $group;

	$this->updateGroup($USER);

	return $return;
}


#############################################################################
sub update
{
	my ($this, $USER) = @_;
	$this->updateGroup($USER);
	my $return = $this->SUPER();

	return $return;
}


#############################################################################
#	Sub
#		updateGroup
#
#	Purpose
#		This takes the group data that we have and compares it to what
#		is in the database for this group.  We determine what nodes have
#		been inserted and what nodes have been removed, then insert and
#		remove them as appropriate.  Lastly we update each group member's
#		orderby.  This way we minimize sql deletes and inserts and do a
#		simple sql update.
#
#	Notes
#		A little discussion on groups here.  This function is a good chunk
#		of code with some interesting stuff going on.  With groups we need
#		to handle the case that the same node (same ID) may be in the group
#		twice in different places in the order.  In general, we don't keep
#		duplicate nodes in a group, but it is implemented to handle the
#		the case of duplicates for completeness.
#
#		Group tables contain 4 columns, tablename_id, rank, node_id, and
#		orderby.  tablename_id is set to the id of the group node that has
#		this node (row) in its group.  Since tablename_id can be the same
#		for multiple rows, we need a secondary key.  rank is the secondary
#		key.  Each time a new row for a group is inserted, we increment the
#		max rank.  This way, each row has a unique key of tablename_id,rank.
#		node_id is the id of the node that belongs to the group.  There can
#		be duplicates of node_id in the same group.  Orderby exists only
#		because we do not want to change rank.  rank is indexed as part of
#		the primary key.  If we were to change rank, we would need to take
#		the hit of the database re-indexing on each update.  So, the orderby
#		field is just there to allow us to specify the order of the nodes
#		in the group without mucking with the primary index.
#
#	Parameters
#		$USER - used for authentication
#
#	Returns
#		True if successful, false otherwise.
#
sub updateGroup
{
	my ($this, $USER) = @_;

	return 0 unless($USER);
	return 0 unless($this->hasAccess($USER, 'w'));

	my $group = $$this{group};
	$group = $this->restrict_type($group);

	my %DIFF;
	my $table = $this->isGroup();
	my $updated = 0;

	my $orgGroup = $this->selectGroupArray();

	# We need to determine how many nodes have been inserted or removed
	# from the group.  We create a hash for each node_id.  For each one
	# that exists in the orginal group, we subract one.  For each one
	# that exists in our current group, we add one.  This way, if any
	# nodes have been removed, they will be negative (exist in the orginal
	# group, but not in the current) and any new nodes will be positive.
	# If there is no change for a particular node, it will be zero
	# (subtracted once for being in the original group, added once for
	# being in the current group).
	foreach (@$orgGroup)
	{
		$DIFF{$_} = 0 unless(exists $DIFF{$_});
		$DIFF{$_}--;
	}
	foreach (@$group)
	{
		$DIFF{$_} = 0 unless(exists $DIFF{$_});
		$DIFF{$_}++;
	}

	my $sql;

	# Actually remove the nodes from the group 
	foreach my $node (keys %DIFF)
	{
		my $diff = $DIFF{$node};

		if($diff < 0)
		{
			my $abs = abs($diff);

			# diff is negative, so we need to remove abs($diff) number
			# of entries.
			$sql = "delete from " . $table . " where " . $table .
				"_id=$$this{node_id} && node_id=$node LIMIT $abs";

			my $rowsAffected = $$this{DB}->{dbh}->do($sql);

			print STDERR "Warning! Wrong number of group members deleted!\n"
				if($abs != $rowsAffected);

			$updated = 1;
		}
		elsif($diff > 0)
		{
			# diff is positive, so we need to insert $diff number
			# of new members for this particular node_id.

			# Find what the current max rank of the group is.
			my $rank = $$this{DB}->sqlSelect('MAX(rank)', $table, 
				$table . "_id=$$this{node_id}");

			$rank ||= 0;

			for(my $i = 0; $i < $diff; $i++)
			{
				$rank++;

				$$this{DB}->sqlInsert($table,
					{ $table . "_id" => $$this{node_id}, 
					rank => $rank, node_id => $node,
					orderby => '0' });

				$updated = 1;
			}
		}
	}

	if($updated)
	{
		# Ok, we have removed and inserted what we needed.  Now we need to
		# reassign the orderby;

		# Clear everything to zero orderby for this group.  We need to do
		# this so that we know which ones we have updated.  If a node was
		# inserted into the middle, all of the orderby's for nodes after
		# that one would need to be incremented anyway.  This way, we reset
		# everything and update each member one at a time, and we are
		# guaranteed not to miss anything.
		$$this{DB}->sqlUpdate($table, { orderby => 0 }, $table .
			"_id=$$this{node_id}");
		
		my $orderby = 0;
		foreach my $id (@$group)
		{
			# This select statement here is only needed to get a specific row
			# and single out a node in the group.  If the database supported
			# "LIMIT #" on the update, we could just say update 'where
			# orderby=0 LIMIT 1'.  So, until the database supports that we
			# need to find the specific one we want using select
			my $rank = $$this{DB}->sqlSelect("rank", $table, $table .
				"_id=$$this{node_id} && node_id=$id && orderby=0", "LIMIT 1");
			
			my $sql = $table . "_id=$$this{node_id} && node_id=$id && " .
				"rank=$rank";
			$$this{DB}->sqlUpdate($table, { orderby => $orderby }, $sql);

			$orderby++;
		}
	}

	$$this{group} = $group;

	return 1;
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
#		group contains sub groups, you will need to use inGroup().
#
#		Also note that this does not hit the database, it just does a simple
#		check of our group array.  This avoids an unnecessary DBI query, but
#		if you have done any inserts or removals without executing an update()
#		you will be checking against data that is not the same as what the
#		database has.  For most general cases, this is probably what you
#		want (considering page loads, etc), but something that you should
#		be aware of.
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
	my $nodeId = $$this{DB}->getId($NODE);
	my $group = $$this{group};

	foreach (@$group)
	{
		return 1 if($_ eq $nodeId);
	}
	
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

	return 0 unless($NODE);

	my $id = $$this{DB}->getId($NODE);
	
	$members = $this->selectNodegroupFlat();
	foreach my $member (@$members)
	{
		return 1 if(($member->getId()) == $id);
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
#		This will insert a node(s) into a nodegroup.  THIS DOES NOT UPDATE
#		THE NODE IN THE DATABASE!  After inserting a node into a group,
#		you must call update() to update the changes.
#
#	Parameters
#		USER - the user trying to add to the group (used for authorization)
#		insert - the node or array of nodes to insert into the group
#		orderby - the criteria of which to order the nodes in the group.
#			This is zero-based.  Meaning that 0 (zero) will insert at
#			the very beginning of the group.
#
#	Returns
#		True (1) if the insert was successful.  If you had previously
#		called selectNodegroupFlat(), you will need to do so again to
#		refresh the list.  False (0), if the user does not have
#		permissions, or failure.
#
sub insertIntoGroup
{
	my ($this, $USER, $insert, $orderby) = @_;
	my $group = $$this{group};
	my $len;
	my $insertref;
	my $rank;	

	return 0 unless($USER);
	return 0 unless($insert);
	return 0 unless($this->hasAccess($USER, "w")); 
	
	# converts to a list reference w/ 1 element if we get a scalar
	$insertref = [$insert] unless(ref ($insert) eq "ARRAY");

	$insertref = $this->restrict_type($insertref);

	$len = int(@$group);
	$orderby ||= $len;
	$orderby = ($orderby > $len ? $len : $orderby);

	# Make sure we only have id's
	foreach (@$insertref)
	{
		$_ = $$this{DB}->getId($_);
	}
	
	# Insert the new nodes into the group array at the orderby offset.
	splice(@$group, $orderby, 0, @$insertref);

	$$this{group} = $group;

	# If a flatgroup exists, it is no longer valid.
	delete $$this{flatgroup} if(exists $$this{flatgroup});

	return 1;
}


#############################################################################
#	Sub
#		removeFromGroup
#
#	Purpose
#		Remove a node from a group.  THIS DOES NOT UPDATE THE NODE IN THE
#		DATABASE! You need to call update() to commit the changes to the
#		database.
#
#	Parameters
#		$NODE - the node to remove
#		$USER - the user who is trying to do this (used for authorization)
#
#	Returns
#		True (1) if the node was successfully removed from the group.
#		False (0) otherwise.  If you had previously called
#		selectNodegroupFlat(), you will need to call it again since
#		things may have significantly changed.
#
sub removeFromGroup 
{
	my ($this, $NODE, $USER) = @_;
	my $success;
	
	return 0 unless($USER);
	return 0 unless($NODE);
	return 0 unless($this->hasAccess($USER, "w"));

	my $node_id = $$this{DB}->getId($NODE);
	my $group = $$this{group};
	my @newgroup;

	for(my $i = 0; $i < @$group; $i++)
	{
		my $id = shift @$group;
		push @newgroup, $id if($id ne $node_id);
	}

	# Assign the new group back to our hash
	$$this{group} = \@newgroup;

	return 1;
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
#		True if successful, false otherwise
#
sub replaceGroup
{
	my ($this, $REPLACE, $USER) = @_;
	my $groupTable = $this->isGroup();

	$this->hasAccess($USER, "w") or return 0; 
	
	$REPLACE = [$REPLACE] if(ref $REPLACE ne "ARRAY");

	$REPLACE = $this->restrict_type($REPLACE);

	# Just replace the group
	$$this{group} = $REPLACE;

	# If a flatgroup exists, it is no longer valid.
	delete $$this{flatgroup} if(exists $$this{flatgroup});

	return 1;
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
#		fieldToXML
#
#	Purpose
#		Convert the field that contains the group structure to an XML
#		format.
#
#	Parameters
#		$DOC - the base XML::DOM::Document object that contains this
#			structure
#		$field - the field of the node to convert (if it is not the group
#			field, we just call SUPER())
#		$indent - string that contains the spaces that this will be indented
#
sub fieldToXML
{
	my ($this, $DOC, $field, $indent) = @_;

	if($field eq "group")
	{
		my $GROUP = new XML::DOM::Element($DOC, "group");
		my $group = $$this{group};
		my $tag;
		my $text;
		my $title;
		my $indentself = "\n" . $indent;
		my $indentchild = $indentself . "  ";

		foreach my $member (@$group)
		{
			$GROUP->appendChild(new XML::DOM::Text($DOC, $indentchild));
			
			$tag = genBasicTag($DOC, "member", "group_node", $member);
			$GROUP->appendChild($tag);
		}

		$GROUP->appendChild(new XML::DOM::Text($DOC, $indentself));

		return $GROUP;
	}
	else
	{
		return $this->SUPER();
	}
}


#############################################################################
sub xmlTag
{
	my ($this, $TAG) = @_;
	my $tagname = $TAG->getTagName();

	if($tagname eq "group")
	{
		my @fixes;
		my @childFields = $TAG->getChildNodes();
		my $orderby = 0;

		foreach my $child (@childFields)
		{
			next if($child->getNodeType() == XML::DOM::TEXT_NODE());

			my $PARSE = Everything::XML::parseBasicTag($child, "nodegroup");

			if(exists $$PARSE{where})
			{
				$$PARSE{orderby} = $orderby;
				$$PARSE{fixBy} = "nodegroup";

				# The where contains our fix
				push @fixes, $PARSE;

				# Insert a dummy node into the group which we can then later
				# fix.
				$this->insertIntoGroup(-1, -1, $orderby);
			}
			else
			{
				$this->insertIntoGroup(-1, $$PARSE{$$PARSE{name}}, $orderby);
			}

			$orderby++;
		}

		return \@fixes if(@fixes > 0);
	}
	else
	{
		return $this->SUPER();
	}

	return undef;
}


#############################################################################
#	Sub
#		applyXMLFix
#
#	Purpose
#		In xmlTag, we returned a hash indicating that we were unable to
#		find a node that one of our group members referenced.  All nodes
#		should be installed now, so we need to go find it and fix the
#		reference.
#
#	Parameters
#		$FIX - the fix that we returned from xmlTag()
#		$printError - set to true if errors should be printed to stdout
#
#	Returns
#		undef if the patch was successful.  $FIX if we were still unable
#		to find the node.
#
sub applyXMLFix
{
	my ($this, $FIX, $printError) = @_;

	if($$FIX{fixBy} ne "nodegroup")
	{
		return $this->SUPER();
	}

	my $where = Everything::XML::patchXMLwhere($$FIX{where});
	my $TYPE = $$where{type_nodetype};
	my $NODE = $$this{DB}->getNode($where, $TYPE);

	unless($NODE)
	{
		print STDERR "Error! Unable to find '$$where{title}' of type \n" .
			"'$$where{type_nodetype}' for field $$where{field}\n"
		  	if($printError);

		return $FIX;
	}

	my $group = $$this{group};

	# Patch our group array with the now found node id!
	$$group[$$FIX{orderby}] = $$NODE{node_id};

	return undef;
}


################################################################################
#	Sub
#		clone
#
#	Purpose
#		Clone the node!  The normal clone doesn't duplicate members of a
#		nodegroup, so we have to do it here specifically.
#
#	Parameters
#		$USER - the user trying to clone this node (for permissions)
#		$newtitle - the new title of the cloned node
#		$workspace - the id or workspace hash into which this node
#			should be cloned.  This is primarily for internal purposes
#			and should not be used normally.  (NOT IMPLEMENTED YET!)
#
#   Returns
#       The newly cloned node, if successful.  undef otherwise.
#
sub clone
{
	my $this = shift;

	# we need $USER for Everything::Node::node::clone() _and_ insertIntoGroup
	my ($USER) = @_;
	my $NODE = $this->SUPER(@_);
	return undef unless (defined $NODE);
	if (defined(my $group = $this->{group})) 
	{
		$NODE->insertIntoGroup($USER, $group);
	}

	# Update the node since the new group info has not been saved yet.
	$NODE->update($USER);

	return $NODE;
}

################################################################################
#	Sub
#		restrict_type
#
#	Purpose
#		Some nodegroups can only hold nodes of a certain type.  This takes a
#		reference to a list of nodes to insert and removes any that don't fit.
#		It also allows nodegroups that have the same restriction -- a usergroup
#		can hold user nodes and other usergroups.
#
#	Parameters
#		$groupref - a reference to a list of nodes to insert into the group
#
#   Returns
#       A reference to a list of nodes allowable in this group.
#
sub restrict_type {
    my ($this, $groupref) = @_;
    my $restricted_type;

	# anything is allowed without a valid restriction
	my $nodetype = getNode($$this{type_nodetype});
    return $groupref unless ($restricted_type = $$nodetype{restrict_nodetype});

    my @cleaned;

    foreach (@$groupref) 
	{
        my $node = getNode($_);

		# check if the member matches directly
        if ($node->{type_nodetype} == $restricted_type) 
		{
            push @cleaned, $_;
        } 

		# check if the member is a nodegroup with similar restrictions
		elsif (defined($node->{type}{restrict_nodetype}))
		{
			if ($node->{type}{restrict_nodetype} == $restricted_type) 
			{
				push @cleaned, $_;
			}
		}
    }
    return \@cleaned;
}

#############################################################################
# End of package
#############################################################################

1;
