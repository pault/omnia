package Everything::Node::popupmenu;

#############################################################################
#   Everything::Node::popupmenu
#		Package the implements the base popupmenu functionality.
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
#		This is called to generate the needed HTML for this popupmenu
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
#		$bindNode - a node ref if this popupmenu is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this popupmenu is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$default - value this object will contain as its initial default.
#			Specify 'AUTO' if you want to use the value of the field this
#			object is bound to, if it is bound
#		$values - an array ref that contains the values of the various
#			radio buttons
#		$labels - (optional) a hashref containing
#			$hash{$values[0...]} = $readableLabel
#
#	Returns
#		The generated HTML for this popupmenu object
#
sub genObject
{
	my ($this, $query, $bindNode, $field, $name, $default, $values,
		$labels, $sortby) = getParamArray(
		"this, query, bindNode, field, name, default, values, labels, sortby", @_);

	my $html = $this->SUPER() . "\n";
	
	if($default eq "AUTO")
	{
		$default = "";
		$default = $$bindNode{$field} if($bindNode);
	}

	$this->addArray($values);
	$this->addLabels($labels);
	
	$html .= $this->genPopupMenu($name, $values, $default, $labels);

	return $html;
}


#############################################################################
# End of package
#############################################################################

1;


