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


#############################################################################
sub construct
{
	my ($this) = @_;

	$$this{group} = $this->selectGroupArray();

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
	my @inserted;
	my @removed;
	my %inOrg;
	my $table = $this->isGroup();
	my $updated = 0;

	# Make sure the table exists first
	$$this{DB}->createGroupTable($table);

	my $orgGroup = $this->selectGroupArray();

	# Find the new nodes that have been added to this group.  If a node
	# is in the original group (seen), then its not new. 
	foreach (@$orgGroup) { $inOrg{$_} = 1; }
	foreach (@$group)
	{
		push @inserted, $_ unless(exists $inOrg{$_});
	}

	# Find the nodes that have been removed from this group.  
	my %inGroup;
	foreach (@$group) { $inGroup{$_} = 1; }
	foreach (@$orgGroup)
	{
		push @removed, $_ unless(exists $inGroup{$_});
	}

	my $sql;

	# Actually remove the nodes from the group 
	foreach my $remove (@removed)
	{
		$sql = "delete from " . $table . " where " . $table .
			"_id=$$this{node_id} && node_id=$remove LIMIT 1";
		$$this{DB}->{dbh}->do($sql);
		$updated = 1;
	}

	my $rank = $$this{DB}->sqlSelect('MAX(rank)', $table, 
		$table . "_id=$$this{node_id}");

	$rank ||= 0;

	# Actually insert the new nodes into the group 
	foreach my $insert (@inserted)
	{
		$rank++;

		$$this{DB}->sqlInsert($table,
			{ $table . "_id" => $$this{node_id}, 
			rank => $rank, node_id => $insert,
			orderby => '0' });

		$updated = 1;
	}

	if($updated)
	{
		# Ok, we have removed and inserted what we needed.  Now we need to
		# reassign the orderby;
		my $orderby = 1;
		foreach my $id (@$group)
		{
			$$this{DB}->sqlUpdate($table, { orderby => $orderby },
				{ $table . "_id" => $$this{node_id} , node_id => $id });

			$orderby++;
		}
	}

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
#		orderby - the criteria of which to order the nodes in the group
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
sub fieldToXML
{
	my ($this, $XMLGEN, $field) = @_;
	my $xml;

	if($field eq "group")
	{
		my $group = $$this{group};
		my $order = 1;

		foreach my $member (@$group)
		{
			my $node = $$this{DB}->getNode($member);
			next unless($node);
			
			$xml .= $XMLGEN->member({ orderby => $order,
				type => "noderef",
				type_nodetype => "$$node{type}{title},nodetype" },
				$$node{title});

			$xml .= "\n";
			
			$order++;
		}

		# Indent the members
		$xml =~ s/^/  /gm;
		
		$xml = $XMLGEN->group({}, "\n" . $xml) . "\n";
	}
	else
	{
		$xml = $this->SUPER();
	}

	return $xml;
}


#############################################################################
sub xmlTag
{
	my ($this, $TAG) = @_;
	my $tagname = $TAG->getTagName();

	if($tagname eq "group")
	{
		my $fixes = [];
		my @childFields = $TAG->getChildNodes();
		print "group - $$this{title}\n";

		foreach my $child (@childFields)
		{
			next if($child->getNodeType() == XML::DOM::TEXT_NODE());

			my $ATTRS = $child->getAttributes();
			my $type = $$ATTRS{type}->getValue();
			my $orderby = $$ATTRS{orderby}->getValue();
			my $name = $child->getFirstChild()->toString();

			if($type ne 'noderef')
			{
				print "Error!  Non noderef item in group '$$this{title}'!\n";
				next;
			}

			$name = Everything::XML::unMakeXmlSafe($name);

			my $ntype = $$ATTRS{type_nodetype}->getValue(); 
			my ($title, $nodetype) = split ',', $ntype;
			my $TYPE = $$this{DB}->getNode($title, $nodetype);
			my $WHERE = { type_nodetype => $$TYPE{node_id}, title => $name };
			my $N = $$this{DB}->getNode($WHERE);
			
			if($N)
			{
				$this->insertIntoGroup(-1, $$N{node_id}, $orderby);
			}
			else
			{
				print "  not found - $name\n";
				$$WHERE{fixBy} = "nodegroup";
				$$WHERE{orderby} = $orderby;

				# The where contains our fix
				push @$fixes, $WHERE;

				# Insert a dummy node into the group which we can then later
				# fix.
				$this->insertIntoGroup(-1, -1, $orderby);
			}
		}

		return $fixes;
	}
	else
	{
		return $this->SUPER();
	}
}


#############################################################################
sub applyXMLFix
{
	my ($this, $FIX, $printError) = @_;

	if($$FIX{fixBy} ne "nodegroup")
	{
		return $this->SUPER();
	}

	print "fixing $$this{title} - $$FIX{title}\n";
	my $NODE = $$this{DB}->getNode($$FIX{title}, $$FIX{type_nodetype});

	unless($NODE)
	{
		print "Error! Unable to find '$$FIX{title}' of type '$$FIX{type_nodetype}'".
			"\nfor field $$FIX{field}\n"; # if($printError);
		return $FIX;
	}

	my $group = $$this{group};
	my $orderby = $$FIX{orderby} - 1;

	$$group[$orderby] = $$NODE{node_id};

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
sub clone {
	my $this = shift;

	# we need $USER for Everything::Node::node::clone() _and_ insertIntoGroup
	my ($USER) = @_;
	my $NODE = $this->SUPER(@_);
	return undef unless (defined $NODE);
	if (defined(my $group = $this->{group})) {
		$NODE->insertIntoGroup($USER, $group);
	}
	return $NODE;
}


#############################################################################
# End of package
#############################################################################

1;
