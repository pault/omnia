package Everything::Node::checkbox;

#############################################################################
#   Everything::Node::checkbox
#		Package the implements the base checkbox functionality.
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
#		This is called to generate the needed HTML for this checkbox
#		form object.
#
#	Parameters
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this checkbox is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this checkbox is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=check name=$name>
#		$checked - a string value of what should be set if the checkbox
#			is checked.  Note that if the checkbox is not checked, it will
#			set the field on the node to "".
#		$default - either "CHECKED", "UNCHECKED", or "AUTO".  Where AUTO
#			will set it based on whatever the bound node's field value is.
#		$label - a text string that is to be a visible label for the
#			checkbox
#
#	Returns
#		The generated HTML for this checkbox object
#
sub genObject
{
	my ($this, $query, $bindNode, $field, $name, $checked, $default, $label) =
		getParamArray(
		"this, query, bindNode, field, name, checked, default, label", @_);
		
	my $html = $this->SUPER() . "\n";
	my $CHECK = "";
	
	if(not defined $default or $default eq "AUTO")
	{
		$CHECK = "checked" if($bindNode &&
			$checked eq $$bindNode{$field});
	}

	$label ||= "";
	$html .= $query->checkbox(-name => $name, -checked => $CHECK,
		-value => $checked, -label => $label);
	
	return $html;
}


#############################################################################
# End of package
#############################################################################

1;

