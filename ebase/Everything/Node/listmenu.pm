package Everything::Node::listmenu;

#############################################################################
#   Everything::Node::listmenu
#		Package the implements the base listmenu functionality.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;


#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This is called to generate the needed HTML for this listmenu
#		form object.  NOTE!!!! This cannot be called from
#		[{nodeFormObject:...}] style htmlcode.  You need to call
#		nodeFormObject() as a function.  This is due to the fact
#		that the $values and $labels are array and hash refs.  You
#		cannot achieve the desired results calling this from htmlcode.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this listmenu is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this listmenu is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$default - value this object will contain as its initial default.
#			This can be either a single value, or an array ref of values
#			that are selected (these must exist in the $values array).
#			Specify 'AUTO' if you want to use the value of the field this
#			object is bound to, if it is bound.
#		$multiple - true (1) if this listmenu should allow multiple
#			selections, false (0) if only single items can be selected.
#		$values - an array ref that contains the values of the items in
#			this menu.
#		$size - the height in rows that should listmenu should be
#		$labels - (optional) a hashref containing
#			$hash{$values[0...]} = $readableLabel
#		$sortby - This specifies the order in which to sort the values.
#			Either 'labels', 'labels reverse', 'values', or
#			'values reverse'.
#
#	Returns
#		The generated HTML for this listmenu object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $default, $multiple,
		$values, $size, $labels, $sortby) = getParamArray(
		"query, bindNode, field, name, default, multiple, values, " .
		"size, labels, sortby", @_);

	$this->clearMenu();
	
	my $html = $this->SUPER() . "\n";
	
	if($default eq "AUTO")
	{
		$default = "";
		$default = [ split("\s*,\s*", $$bindNode{$field}) ]  if($bindNode);
	}

	$this->addArray($values);
	$this->addLabels($labels);
	$this->sortMenu($sortby);

	$html .= $this->genListMenu($query, $name, $default, $size, $multiple);

	return $html;
}


#############################################################################
#	Sub
#		cgiUpdate
#
#	Purpose
#		This is called by the system if all cgiVerify()'s have succeeded
#		and it is time to update the node(s).  This will only be called
#		if this object is bound to a node that it needs to update.
#		This default implementation just assigns the value of the CGI
#		object to the bound node{field}.
#
#	Parameters
#		$query - the CGI object that contains the incoming CGI parameters.
#			This is used to find any associated parameters that this
#			object created.
#		$name - the $name passed to genObject() so this can reconstruct
#			the fields that it generated and retrieve the needed data
#		$NODE - the node object that this field is bound to (as reported by
#			cgiVerify).  This is the node that all updates should be made
#			to.  NOTE!  Do not call update() on this node!  That will be
#			handled by the system.
#		$overrideVerify - If (for some reason) this should not check to
#			to see if the nodetype would allow us to update this field.
#			Basically, opUpdate() in HTML.pm will pass true if the user
#			doing this update is a god, and therefore should have complete
#			access to everything.  True if we should allow anything, false
#			if we need to check with the nodetype.
#
#	Returns
#		1 (true) if successful, 0 (false) otherwise
#
sub cgiUpdate
{
	my ($this, $query, $name, $NODE, $overrideVerify) = @_;
	my $field = $this->getBindField($query, $name);

	# Make sure this is not a restricted field that we cannot update
	# directly.
	return 0 unless($overrideVerify or $NODE->verifyFieldUpdate($field));

	my @values = $query->param($name);
	my $value = join(',', @values);
	
	$value ||= "";
	$$NODE{$field} = $value;

	return 1;
}

#############################################################################
# End of package
#############################################################################

1;


