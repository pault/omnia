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
#		gets re-constructed with the new data.
#
sub construct
{
	my ($this) = @_;
	my $field;
	my $dfield;
		
	# We are not physically derived from node (would cause inf loop),
	# but we want its functionality...
	Everything::Node::node::construct($this);

	# Special case where this is the 'nodetype' nodetype
	$$this{type} = $this if($$this{node_id} == 1);

	# Now we need to derive ourselves and assign the derived values
	my $PARENT = $$this{DB}->getNode($$this{extends_nodetype});

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
		"defaultguest_permission" => 1
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
			elsif($field =~ /default.*access/)
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
	Everything::Node::node::destruct($this);

	# Release any object refs that we got
	delete $$this{tableArray};
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
sub getNodeKeys
{
	my ($this, $forExport) = @_;
	return Everything::Node::node::getNodeKeys($this, $forExport);
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
#		$TYPE - the name, id, or hash of the nodetype to get the default
#			permissions for.
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
sub isGroup
{
	return 0;
}


#############################################################################
sub hasVars
{
	return 0;
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
sub getFieldDatatype
{
	my ($this, $field) = @_;

	return Everything::Node::node::getFieldDatatype($this, $field);
}

#############################################################################
#	Sub
#		insert
#
sub insert
{
	return Everything::Node::node::insert(@_);
}


#############################################################################
#	Sub
#		update
#
#	Purpose
#		Update the given node in the database.
#
sub update
{
	return Everything::Node::node::update(@_);
}


#############################################################################
#	Sub
#		nuke
#
sub nuke
{
	return Everything::Node::node::nuke(@_);
}



#############################################################################
# End of package
#############################################################################

1;

