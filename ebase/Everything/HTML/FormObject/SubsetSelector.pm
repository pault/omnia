package Everything::HTML::FormObject::SubsetSelector;

#############################################################################
#   Everything::HTML::FormObject::SubsetSelector
#		Package the implements the base SubsetSelector functionality.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;

use Everything::HTML::FormObject::FormMenu;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::FormMenu");

#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This is called to generate the needed HTML for this SubsetSelector
#		form object.  It consists of a list box in a table with buttons
#		to the right that allow the user to move an item up or down in
#		the group order, or remove it from the group.
#
#	Notes
#		When using this form object, you will need to include two
#		javascript functions, findFormObject() and moveGroupItem().  ie
#		on the page that you use this form object do:
#		[{includeJS: findFormObject, moveGroupItem}]
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this SubsetSelector is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$color - a hex string (ie '#ffcc00') for the background color of
#			this group editor.
#
#	Returns
#		The generated HTML for this SubsetSelector object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $default, $size, $color,
		$srclabel, $destlabel) = 
		getParamArray(
		"query, bindNode, field, name, default, size, color, " .
		"srclabel, destlabel", @_);

	my $select = new Everything::HTML::FormObject::FormMenu();
	my ($key, $var) = split(':', $field);
	my $srcname = $name . "_src";
	
	$color ||= '#cc99ff';
	$default ||= 'AUTO';
	$size ||= 20;

	if($default eq "AUTO" && $bindNode)
	{
		if($var)
		{
			my $vars = $bindNode->getHash($key);
			$default = $$vars{$var};
		}
		else
		{
			$default = $$bindNode{$key};
		}
	}
	
	my @selected = split(',', $default);
	my $removed = $this->removeItems(\@selected);
	$select->addArray(\@selected);
	$select->addLabels($removed, 0);

	my $html = "<table border='0' bgcolor='$color' cellspacing='0'>\n";
	$html .= "<tr><td>\n";
	
	$html .= "<b><font size=2>$srclabel</font></b><br>\n" if($srclabel);
	$html .= $this->SUPER::genObject($query, $bindNode, $field, $name) . "\n";
	$html .= $this->genListMenu($query, $srcname, undef, $size);

	# Generate the hidden form field that holds the list of node id's
	# for us.  This is what we actually get our data from when the
	# form is submitted.
	$html .= $query->hidden(-name => $name . '_values', -value => $default,
		-override => 1);
	
	$html .= "</td><td valign='center' align='center'>\n";
	$html .= $query->button(-name => $name . "_add", -value => ">>>",
		-onClick => "selectItem('$srcname', '$name')",
		-onDblClick => "selectItem('$srcname', '$name')");
	$html .= "<br>\n";
	$html .= $query->button(-name => $name . "_remove",
		-value => "<<<",
		-onClick => "selectItem('$srcname', '$name', 0)", 
		-onDblClick => "selectItem('$srcname', '$name', 0)") . "\n";
	$html .= "</td><td>\n";

	$html .= "<b><font size=2>$destlabel</font></b><br>\n" if($destlabel);
	$html .= $select->genListMenu($query, $name, undef, $size);
	$html .= "</td><td valign='center' align='center'>\n";
	$html .= $query->button(-name => $name . "_up", -value => "Up",
		-onClick => "moveSelectItem('$name', -1)",
		-onDblClick => "moveSelectItem('$name', -1)");
	$html .= "<br>\n";
	$html .= $query->button(-name => $name . "_down", -value => "Down",
		-onClick => "moveSelectItem('$name', 1)", 
		-onDblClick => "moveSelectItem('$name', 1)") . "\n";
	$html .= "</td></tr></table>\n";
	
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
	my $values = $query->param($name . '_values');
	my $field = $this->getBindField($query, $name);
	my $var;

	($field, $var) = split(':', $field);

	if($var)
	{
		my $vars = $NODE->getHash($field);
		$$vars{$var} = $values;
		$NODE->setHash($vars, $field);
	}
	else
	{
		$$NODE{$field} = $values;
	}

	return 1;
}

#############################################################################
# End of package
#############################################################################

1;



