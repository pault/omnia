package Everything::Node::nodetype;

#############################################################################
#   Everything::Node::nodetype
#       Package the implements the base nodetype functionality
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything::Node::node;
use Everything::Security;

#############################################################################
#	Sub
#		construct
#
#	Purpose
#		The constructor for a nodetype is rather involved.  We derive
#		the nodetype when it is constructed.  If a nodetype up the
#		chain changes, the cache needs to be flushed so that the nodetype
#		gets re-constructed with the new data.  If you change
#
sub construct
{
	my ($this) = @_;
	my $field;
	my $dfield;
		
	# We are not physically derived from node (would cause inf loop),
	# but we want its functionality...
	$this->SUPER();

	# Special case where this is the 'nodetype' nodetype
	$$this{type} = $this if($$this{node_id} == 1);

	# Now we need to derive ourselves and assign the derived values
	my $PARENT;
	
	if($$this{node_id} == 1)
	{
		# This is the nodetype nodetype.  We don't want to "load" the
		# node nodetype (would cause infinite loop).  So, we need to 
		# kinda fake it.
		my $nodeid = $$this{DB}->sqlSelect("node_id", "node",
			"title='node' && type_nodetype=1");
		my $cursor = $$this{DB}{dbh}->prepare_cached("select * from nodetype " .
			"left join node on nodetype_id=node_id where nodetype_id=$nodeid");

		if($cursor->execute())
		{
			$PARENT = $cursor->fetchrow_hashref();
			$cursor->finish();
		}
	}
	elsif($$this{extends_nodetype} > 0) # Zero is a dummy location thing 
	{
		$PARENT = $$this{DB}->getNode($$this{extends_nodetype});
	}

	
	# We need to derive the following fields:
	my $derive =
	{
		"sqltable" => 1,
		"grouptable" => 1,
		"defaultauthoraccess" => 1,
		"defaultgroupaccess" => 1,
		"defaultotheraccess" => 1,
		"defaultguestaccess" => 1,
		"defaultgroup_usergroup" => 1,
		"defaultauthor_permission" => 1,
		"defaultgroup_permission" => 1,
		"defaultother_permission" => 1,
		"defaultguest_permission" => 1, 
		"maxrevisions" => 1
	};

	# Copy the fields that are to be derived into new hash entries.  This
	# way we can keep the actual "node" data clean.  That way if/when we
	# update this node, we don't corrupt the database.
	foreach $field (keys %$derive)
	{
		$dfield = "derived_" . $field;
		$$this{$dfield} = $$this{$field};
	}
	
	if($PARENT)
	{
		foreach $field (keys %$derive)
		{
			# We are only modifying the derived fields.  We want to
			# leave the real fields alone
			$field = "derived_" . $field;
			
			# If a field in a nodetype is '-1', this field is derived from
			# its parent.
			if($$this{$field} eq "-1")
			{
				$$this{$field} = $$PARENT{$field};
			}
			elsif(($field =~ /default.*access/) && ($$PARENT{$field} ne ""))
			{
				$$this{$field} = Everything::Security::inheritPermissions(
						$$this{$field}, $$PARENT{$field});
			}
			elsif(($field =~ /sqltable$/) && ($$PARENT{$field} ne ""))
			{
				# Inherited sqltables are added onto the list.  Derived
				# nodetypes "extend" parent nodetypes.
				$$this{$field} .= "," if($$this{$field} ne "");
				$$this{$field} .= "$$PARENT{$field}";
			}
			elsif(($field =~ /grouptable$/) && ($$PARENT{$field} ne "") &&
					($$this{$field} eq ""))
			{
				# We are inheriting from a group nodetype and we have not
				# specified a grouptable, so we will use the same table
				# as our parent nodetype.
				$$this{$field} = $$PARENT{$field};
			}
		}
	}

	# Store an array of all the table names that nodes of this type
	# need to join on.  If there are no tables that this joins on, this
	# will just be an empty array.
	my @tmp = split ',', $$this{derived_sqltable};
	$$this{tableArray} = \@tmp;

	return 1;
}


#############################################################################
sub destruct
{
	my ($this) = @_;

	# Release any object refs that we got
	delete $$this{tableArray};

	# Delete the base stuff
	#$this->SUPER();
}


#############################################################################
#	Sub
#		insert
#
#	Purpose
#		Make new nodetypes derive from 'node' automatically if they do
#		not have a parent specified.
#
#	Returns
#		The inserted node id
#
sub insert
{
	my ($this) = @_;

	if((not defined $$this{extends_nodetype}) or
		($$this{extends_nodetype} == 0))
	{
		my $N = $$this{DB}->getType('node');
		$$this{extends_nodetype} = $$N{node_id};
	}

	return $this->SUPER();
}


#############################################################################
#	Sub
#		update
#
#	Purpose
#		This allows the default "node" to actually update our node, but
#		we need to flush the cache in the case of an update to a nodetype
#		due to the fact that some other nodetypes may derive from this
#		nodetype.  Those derived nodetypes would need to be reloaded and
#		reinitialized, otherwise we may get weird data.
#
sub update
{
	my ($this) = @_;

	my $result = $this->SUPER();

	# If the nodetype was successfully updated, we need to flush the
	# cache to make sure all the nodetypes get reloaded.
	$$this{DB}{cache}->flushCacheGlobal() if($result);

	return $result;
}


#############################################################################
#	Sub
#		getTableArray
#
#	Purpose
#		Every nodetype keeps an array of the tables that nodes of its
#		type need to join on.  This will return an array of those table
#		names.
#
#	Parameters
#		$nodeTable - the node table is usually assumed, but if you want
#			it included, pass true (ie 1).  undef otherwise.
#
#	Returns
#		An array ref of the table names that nodes of this type need
#		to join on.  Note that this array is a copy so feel free to
#		modify it in any way.
#
sub getTableArray
{
	my ($this, $nodeTable) = @_;
	my @tables;

	push @tables, @{$$this{tableArray}} if(defined $$this{tableArray});
	push @tables, "node" if($nodeTable);

	return \@tables;
}


#############################################################################
#	Sub
#		getDefaultTypePermissions
#
#	Purpose
#		This gets the default permissions for the given nodetype.  This
#		is NOT the permissions for the nodetype itself.  Rather, these
#		are the permissions that nodes of this type inherit from.  Hence,
#		the default TYPE permissions.
#
#	Parameters
#		$class - the class of user.  Either "author", "group", "guest",
#			or "other".  This can be obtained by calling
#			getUserNodeRelation().
#
#	Returns
#		A string that contains the default permissions of the given
#		nodetype.
#
sub getDefaultTypePermissions
{
	my ($this, $class) = @_;

	my $field = "derived_default" . $class . "access";
	return $$this{$field};
}


#############################################################################
#	Sub
#		getParentType
#
#	Purpose
#		Get the parent nodetype that this nodetype derives from.
#
#	Returns
#		A nodetype that this nodetype derives from.  undef if this nodetype
#		does not derive from anything.
#
sub getParentType
{
	my ($this) = @_;

	if($$this{extends_nodetype} != 0)
	{
		return $$this{DB}->getType($$this{extends_nodetype});
	}

	return undef;
}


#############################################################################
#	Sub
#		hasTypeAccess
#
#	Purpose
#		The hasAccess() function in Node.pm checks permissions on a specific
#		node.  If you call that on a nodetype, you are checking the
#		permissions for that node, NOT the permissions for all nodes of
#		that type.
#
#		This checks permissions for the default permissions for all nodes
#		of this type.  This is useful for checking permissions for create
#		operation since the node you are trying to create does not yet
#		exist so you can't test the access on it.
#
#	Parameters
#		$USER - the user to check access for
#		$modes - same as hasAccess()
#
#	Returns
#		1 (true) if the user has access to all modes given.  0 (false)
#		otherwise.  The user must have access for all modes given for this to
#		return true.  For example, if the user has read, write and delete
#		permissions, and the modes passed were "wrx", the return would be
#		0 since the user does not have the "execute" permission.
#
sub hasTypeAccess
{
	my ($this, $USER, $modes) = @_;

	# Create a dummy node of this type to do a check on.
	my $dummy = $$this{DB}->getNode("dummy_access_node", $this,
		"create force");

	return $dummy->hasAccess($USER, $modes);
}


#############################################################################
# End of package
#############################################################################

1;

