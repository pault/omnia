package Everything::Node::node;

#############################################################################
#   Everything::Node::node
#	   Package the implements the base node functionality
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use DBI;
use Everything;
use Everything::NodeBase;

#############################################################################
sub construct
{
	my ($this) = @_;

	return 1;
}


#############################################################################
sub destruct
{
	my ($this) = @_;

	return 1;
}


#############################################################################
#	Sub
#		insert
#
#	Purpose
#		Insert this node object into the database.  If it already exists
#		in the database, this will do nothing, unless the operation is
#		forced.  If it is forced, it will make another entry (if
#		duplicates are allowed)
#	
sub insert
{
	my ($this, $USER) = @_;
	my $node_id = $$this{node_id};
	my $user_id = $USER->getId() if(ref $USER);

	$user_id ||= $USER;
	
	return 0 unless($this->hasAccess($USER, "c"));

	# If the node_id is not zero, this has already been inserted and
	# we are not forcing it.
	return $node_id if($node_id > 0);

	if($$this{type}{restrictdupes})
	{
		# Check to see if we already have a node of this title.
		my $id = $$this{type}->getId();

		my $DUPELIST = $$this{DB}->sqlSelect("*", "node", "title=" .
				$this->quoteField("title") . " && type_nodetype=" .
				$id);

		if ($DUPELIST)
		{
			# A node of this name already exists and restrict dupes is
			# on for this nodetype.  Don't do anything
			return 0;
		}
	}

	$$this{DB}->sqlInsert("node",
			{title => $$this{title},
			type_nodetype => $$this{type_nodetype},
			author_user => $user_id,
			hits => 0,
			-createtime => 'now()'});

	# Get the id of the node that we just inserted.
	$node_id = $$this{DB}->sqlSelect("LAST_INSERT_ID()");

	my $typename = $$this{type}{title};
	if($typename eq "document" or $typename eq "superdoc")
	{
		my $a = 0;
	}
	
	# Now go and insert the appropriate rows in the other tables that
	# make up this nodetype;
	my $tableArray = $$this{type}->getTableArray();
	foreach my $table (@$tableArray)
	{
		my %tableData;
		my @fields = $$this{DB}->getFields($table);

		$tableData{$table . "_id"} = $node_id;
		foreach (@fields)
		{
			$tableData{$_} = $$this{$_} if(exists $$this{$_});
		}
		
		$$this{DB}->sqlInsert($table, \%tableData);
	}

	# Now that it is inserted, we need to force get it.  This way we
	# get all the fields.  We then clear the $this hash and copy in
	# the info from the newly inserted node.  This way, the user of
	# the API just calls $NODE->insert() and their node gets filled
	# out for them.
	my $newNode = $$this{DB}->getNode($node_id, 'force');
	undef %$this;
	@$this{keys %$newNode} = values %$newNode;

	return $node_id;
}


#############################################################################
#	Sub
#		update
#
#	Purpose
#		Update the given node in the database.
#
#	Parameters
#		$USER - the user attempting to update this node (used for
#			authorization)
#
#	Returns
#		The node id of the node updated if successful, 0 (false) otherwise.
#
sub update
{
	my ($this, $USER) = @_;
	my %VALUES;
	my $tableArray;
	my $table;
	my @fields;
	my $field;

	return 0 unless ($this->hasAccess($USER, "w")); 

	# Cache this node since it has been updated.  This way the cached
	# version will be the same as the node in the db.
	$this->cache();

	# We extract the values from the node for each table that it joins
	# on and update each table individually.
	$tableArray = $$this{type}->getTableArray(1);
	foreach $table (@$tableArray)
	{
		undef %VALUES; # clear the values hash.

		@fields = $$this{DB}->getFields($table);
		foreach $field (@fields)
		{
			if (exists $$this{$field})
			{ 
				$VALUES{$field} = $$this{$field};
			}
		}

		# we don't want to chance mucking with the primary key
		# So, remove this from the hash
		delete $VALUES{$table . "_id"}; 

		$$this{DB}->sqlUpdate($table, \%VALUES, $table . "_id=$$this{node_id}");
	}

	return $$this{node_id};
}


#############################################################################
#	Sub
#		nuke
#
#	Purpose
#		This removes a node and all associated data with it from the
#		database.  All basic nodes have the node data and link data in
#		the database.  This implementation takes care of that data and
#		nothing else.  If there are other nodetypes that contain other
#		info in the database (nodegroups, for example), they will need
#		to override this method and do the appropriate cleanup for their
#		data.  However, they should always make sure to call $this->SUPER()
#		at some point so this gets executed to clean up the basic stuff.
#
#		Also note that after this is called, the node hash that the caller
#		is holding onto is considered a "dummy" node.  It no longer exists
#		in the database.  However, it is still a "Node" object, so you
#		could immediately turn around an re-insert it and everything should
#		be fine.
#
#	Parameters
#		$USER - a user node object of the user trying to nuke this node.
#			Used for authorization.
#
#	Returns
#		0 (zero) if nothing was deleted (this can be caused by the node
#		not existing in the database, or the user not having permission).
#		A number representing the number of rows deleted from the database.
#		Essentially, false if the nuke failed, true if it succeeded.
#
sub nuke
{
	my ($this, $USER) = @_;
	my $result = 0;

	$$this{DB}->getRef($USER);

	return 0 unless($this->hasAccess($USER, "d"));

	# Delete this node from the cache that we keep.
	$this->removeFromCache();

	my $tableArray = $$this{type}->getTableArray(1);
	foreach my $table (@$tableArray)
	{
		$result += $$this{DB}->{dbh}->do("DELETE FROM $table WHERE " . $table .
				"_id=". $this->getId());
	}

	# Remove all links that go from or to this node that we are deleting
	$$this{DB}->{dbh}->do("DELETE FROM links WHERE to_node=" . 
		   $this->getId() . " OR from_node=" . $this->getId());

	# Clear out the node id so that we can tell this is a "non-existant"
	# node.
	$$this{node_id} = 0;

	return $result;
}


#############################################################################
#	Sub
#		getNodeKeys
#
#	Purpose
#		We store instance info in the hash along with the database
#		information.  This tends to clutter up the hash with keys/values
#		that don't belong/exist in the database.  So, if you need just
#		the keys of the values that represent the columns in the database,
#		this function is your friend.
#
#		Everything::Node::node::getNodeKeys() implements the base for
#		the hierarchy.
#
#	Parameters
#		$forExport - true if you want the keys that are considered
#			to be "exportable", 0 (false) otherwise.
#			When a node is exported (ie to XML), there are some fields that
#			exist in the database that we don't want exported (doesn't make
#			sense to export the "hits" field).  Setting this to true, will
#			cause this function to not return any fields that don't make
#			sense for export.
#
#	Returns
#		A hashref that is basically what you would get if you just got
#		the data from the database.
#
sub getNodeKeys
{
	my ($this, $forExport) = @_;
	my $keys = $this->getNodeDatabaseHash();
	
	if($forExport)
	{
		# We want the keys that are good for exporting (ie XML), in
		# addition to the "bogus" keys that we have, there are some
		# fields that just don't make sense for exporting.
		delete $$keys{createtime};
		delete $$keys{hits};
		delete $$keys{reputation};
		delete $$keys{lockedby_user};
		delete $$keys{locktime};
		
		foreach my $k (keys %$keys)
		{
			# We do not want to export ids!
			delete $$keys{$k} if($k =~ /_id$/);
		}
	}

	return $keys;
}




#############################################################################
#	Sub
#		isGroup
#
#	Purpose
#		Is this node a nodegroup?  Note, derived nodetypes that are groups
#		will need to override this function to return the appropriate value.
#
#	Returns
#		The name of the table the nodegroup uses to store its group info
#		if the node is a nodegroup.  0 (false) if not.
#
sub isGroup
{
	return 0;
}


#############################################################################
#	Sub
#		getFieldDatatype
#
#	Purpose
#		Each field in the node contains some kind of data.  This can either
#		be a raw value (hits = 302), a reference to a node (author_user = 184),
#		an array of values (usually group ids), or a hash of vars ( 'vars'
#		field on setting).  This is needed so that when we export a node
#		to XML, we know what kind of datatype the field represents.
#
#		For standard nodes, the fields are either a noderef, or a strict
# 		value.  If a nodetype has other fields, they need to override this
# 		function and return the appropriate type.
#
#		Valid return values are "literal_value", "noderef", "group", or "vars".
#
#	Parameters
#		$field - the field to get the datatype of
#
#	Returns
#		Either "value" or "noderef".  If a nodetype needs to return
#		something else, they need to override this function.
#
sub getFieldDatatype
{
	my ($this, $field) = @_;

	return "noderef" if($field =~ /_\w+$/ and $$this{$field} =~ /^\d+$/);
	return "literal_value";
}


#############################################################################
#	Sub
#		hasVars
#
#	Purpose
#		Nodetypes that contain a "hash" variable table should override
#		this and return true.  This is a check to see if a given node
#		has a vars setting.
#
sub hasVars
{
	return 0;
}


#############################################################################
# End of package
#############################################################################

1;
