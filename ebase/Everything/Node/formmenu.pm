package Everything::Node::formmenu;

use strict;
use Everything;

#############################################################################
#   Everything::Node::formmenu
#		Package the implements the base formmenu functionality.
#
#	This is the base of all pop-up or listbox menus.  This package
#	does not directly support the standard API for form objects.
#	It is not intended to be used in that manner, because this just
#	implements the base functionality that all menus will use.
#
#	You can use this directly to do make some very custom menus if
#	needed.  However, the derived classes of this will provide specific
#	functionality that will make certain types of menus easier to
#	do.
#
#	Use the various addX() functions to add items to the menu. Once
#	the menu is populated with the desired items, call genPopupMenu()
#	or genListMenu()
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################



#############################################################################
sub getValuesArray
{
	my ($this) = @_;

	$$this{VALUES} ||= [];
	return $$this{VALUES};
}


#############################################################################
sub getLabelsHash
{
	my ($this) = @_;

	$$this{LABELS} ||= {};
	return $$this{LABELS};
}


#############################################################################
sub clearMenu
{
	my ($this) = @_;
	$$this{VALUES} = [];
	$$this{LABELS} = {};
}


#############################################################################
#	Sub
#		sortMenu
#
#	Purpose
#		Utility function used to sort the menu listing by certain
#		criteria.
#
#	Parameters
#		$sortby - This specifies the order in which to sort the values.
#			Either 'labels', 'labels reverse', 'values', or
#			'values reverse'.
#		$values - (optional) an array ref of values for the menu.  If
#			undef, it is assumed that you want to sort what is in the
#			menu at the time this function is called.
#		$labels - (not needed if sorting by values) hash ref of
#			'value' => 'label name'
#
#	Returns
#		An array ref of the sorted values for the menu.
#
sub sortMenu
{
	my ($this, $sortby, $values, $labels) = @_;
	my @sorted;
	my $sortThis = 0;
	
	unless($values)
	{
		$values = $this->getValuesArray();
		$labels = $this->getLabelsHash();
		$sortThis = 1;
	}

	if($sortby eq 'labels')
	{
		@sorted = sort { $$labels{$a} cmp $$labels{$b} } @$values;
	}
	elsif($sortby eq 'reverse labels')
	{
		@sorted = sort { $$labels{$b} cmp $$labels{$a} } @$values;
	}
	elsif($sortby eq 'values')
	{
		@sorted = sort { $a cmp $b } @$values;
	}
	elsif($sortby eq 'reverse values')
	{
		@sorted = sort { $b cmp $a } @$values;
	}

	$$this{VALUES} = \@sorted if($sortThis);
	
	return \@sorted;
}


#############################################################################
#	Sub
#		addType
#
#	Purpose
#		Add all nodes of the given type to the menu.  This is useful for
#		given an option to select a given user, nodetype, etc.
#
#	Parameters
#		$type - the string name of the nodetype of the nodes to add.
#		$USER - (optional) the user trying to do this.  If a user is passed
#			this will omit the nodetypes that the user does not
#			have access to (access specified by $perm)
#		$perm - (optional) the permission needed for the user to have
#			a node in the menu.  This is required if you specify a user.
#		$sortby - This specifies the order in which to sort the values.
#			Either 'labels', 'labels reverse', 'values', or
#			'values reverse'.
#
#	Returns
#		True if successful, false otherwise.
#
sub addType
{
	my ($this, $type, $USER, $perm, $sortby) = @_;
	my $TYPE = $$this{DB}->getType($type);
	my $typeid = $$TYPE{node_id} if(defined $TYPE);
	my $NODES = $$this{DB}->getNodeWhere({type_nodetype => $typeid});
	my $NODE;
	my $gValues = $this->getValuesArray();
	my $gLabels = $this->getLabelsHash();
	my @values;

	foreach $NODE (@$NODES)
	{
		next unless((not $USER) or ($NODE->hasAccess($USER, $perm)));
		$$gLabels{$$NODE{node_id}} = $$NODE{title};
		push @values, $$NODE{node_id};
	}

	if($sortby)
	{
		my $sort = $this->sortMenu($sortby, \@values, $gLabels);
		push @$gValues, @$sort;
	}
	else
	{
		push @$gValues, @values;
	}

	return 1;
}


#############################################################################
#	Sub
#		addGroup
#
#	Purpose
#		Given the name of the group, add all of the nodes in that group.
#
#	Parameters
#		$GROUP - the group node in which to add its group members to
#			the menu
#		$USER - (optional) the user trying to do this.  If a user is passed
#			this will omit nodes in the group that the user does not
#			have access to
#		$perm - (optional) the permission needed for the user to have
#			a node in the menu.  This is required if you specify a user.
#		$sortby - This specifies the order in which to sort the values.
#			Either 'labels', 'labels reverse', 'values', or
#			'values reverse'.
#
#	Returns
#		True if successful, false otherwise.
#
sub addGroup
{
	my ($this, $GROUP, $showType, $USER, $perm, $sortby) = @_;
	my $groupnode;
	my $NODE;
	my $GROUPNODES;
	my $gValues = $this->getValuesArray();
	my $gLabels = $this->getLabelsHash();
	my @values;
	
	$GROUPNODES = $$GROUP{group};
	foreach $groupnode (@$GROUPNODES)
	{
		$NODE = $$this{DB}->getNode($groupnode);
		next unless((not $USER) or ($NODE->hasAccess($USER, $perm)));
		
		my $label = $$NODE{title};
		$label .= " ($$NODE{type}{title})" if($showType);
		
		$$gLabels{$$NODE{node_id}} = $label;
		push @values, $$NODE{node_id};
	}

	if($sortby)
	{
		my $sort = $this->sortMenu($sortby, \@values, $gLabels);
		push @$gValues, @$sort;
	}
	else
	{
		push @$gValues, @values;
	}

	return 1;
}


#############################################################################
#	Sub
#		addHash
#
#	Purpose
#		Given a hashref, add the contents to the menu.  The keys of the
#		hash should be the values of the menu.  The values of the hash
#		should be the string that is to be seen by the user.  For example,
#		if you want a popup menu with labels of "yes" and "no" and values
#		of '1' and '0', your hash should look like:
#			{ '1' => "yes", '0' => "no"}
#
#	Parameters
#		$hashref - the reference to the hash that you want to add to the
#			menu.
#		$keysAreLabels - true if the keys of the hash should be what
#			is visible to the user in the menu.  false if the values
#			of the hash are what should be the labels.  This is so you
#			can use your hash data structure as it is without needing
#			to make it conform to what this expects.  For example, if
#			you have a hash that is { 'yes' => 1, 'no' => 0 }, pass true.
#		$sortby - (optional) This specifies the order in which to sort the
#			values. Either 'labels', 'labels reverse', 'values', or
#			'values reverse'.
#
#	Returns
#		True if successful, false otherwise.
#
sub addHash
{
	my ($this, $hashref, $keysAreLabels, $sortby) = @_;
	my $key;
	my $gValues = $this->getValuesArray();
	my $gLabels = $this->getLabelsHash();
	my @values;

	foreach $key (keys %$hashref)
	{
		if($keysAreLabels)
		{
			# the labels hash must labels{value} = 'label name'
			$$gLabels{$$hashref{$key}} = $key;
			push @values, $$hashref{$key};
		}
		else
		{
			$$gLabels{$key} = $$hashref{$key};
			push @values, $key;
		}
	}

	if($sortby)
	{
		my $sort = $this->sortMenu($sortby, \@values, $gLabels);
		push @$gValues, @$sort;
	}
	else
	{
		push @$gValues, @values;
	}

	return 1;
}


#############################################################################
#	Sub
#		addArray
#
#	Purpose
#		If you just have an array of items you want, you can pass them
#		to this method to have them added.  It is assumed that the
#		array is in the order that you want the items to appear in the
#		list.
#
#	Parameters
#		$values - an array ref of the values to add to the list
#
#	Returns
#		True if successful, false otherwise
#
sub addArray
{
	my ($this, $values) = @_;

	return unless($values);
	my $gValues = $this->getValuesArray();

	push @$gValues, @$values;

	return 1;
}


#############################################################################
#	Sub
#		addLabels
#
#	Purpose
#		Add new labels to the menu.
#
#	Paramters
#		$labels - a hashref of labels to add.  It can be either
#			'value' => 'label', or 'label' => 'value'.  Just
#			specify $keysAreLabels as appropriate.
#		$keyAreLabels - true if the keys of the hash are to be the visible
#			labels, false if the values of the hash are to be the visible
#			labels.
#
#	Returns
#		True if successful, false otherwise
#
sub addLabels
{
	my ($this, $labels, $keysAreLabels) = @_;

	return unless($labels);
	my $gLabels = $this->getLabelsHash();

	$keysAreLabels ||= 0;

	if($keysAreLabels)
	{
		@$gLabels{values %$labels} = keys %$labels;
	}
	else
	{
		@$gLabels{keys %$labels} = values %$labels;
	}

	return 1;
}


#############################################################################
#	Sub
#		genPopupMenu
#
#	Purpose
#		Based on how the menu was set up, generate the HTML for the popup
#		menu and return it.
#
#	Parameters
#		$cgi - the CGI object that we should use to create the HTML
#		$name - The string name of the form item
#		$selected - the option that is selected by default.  This should
#			be one of the values in the values array.
#
#	Returns
#		The HTML for the popup menu
#
sub genPopupMenu
{
	my ($this, $cgi, $name, $selected) = @_;

	return $cgi->popup_menu(-name => $name,
	                        -values => $this->getValuesArray(),
	                        -default => $selected,
	                        -labels => $this->getLabelsHash());
}


#############################################################################
#	Sub
#		genListMenu
#
#	Purpose
#		Create the HTML needed for a scrolling list form item.
#
#	Parameters
#		$cgi - the CGI object that we should use to generate the HTML
#		$name - the string name of the form item
#		$selected - the name of the option that is selected by default.
#			An array reference if the default selection is more than one.
#			If blank, then nothing is selected by default.
#		$size - <optional> the number of options (lines) visible
#		$multi - <optional> 1 (true) if this list item should allow
#			multiple selections	0 (false) if not.
#
#	Returns
#		The HTML for this scrolling list form item
#
sub genListMenu
{
	my ($this, $cgi, $name, $selected, $size, $multi) = @_;

	# We want an array.  If we have a scalar, make it an array with one elem
	$selected = [$selected] unless(ref $selected eq "ARRAY");

	$multi ||= 0;
	$size ||= 6;

	return $cgi->scrolling_list(-name => $name,
	                            -values => $this->getValuesArray(),
	                            -default => $selected,
	                            -size => $size,
	                            -multiple => $multi,
	                            -labels => $this->getLabelsHash());
}


#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This is called to generate the needed HTML for this menu object.
#		NOTE!!! This does virtually nothing!  You will either need to
#		call genPopupMenu or genListMenu manually if you want to use this
#		object directly.  Basically, this object can be used create custom
#		menus that the other derived objects of this object do not provide.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this popupmenu is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this popupmenu is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#
#	Returns
#		The generated HTML for this popupmenu object
#
sub genObject
{
	my ($this) = @_;

	return $this->SUPER();
}


#############################################################################
# End of Package Everything::Node::formmenu
#############################################################################

1;
