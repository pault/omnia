package Everything::Node::textfield;

#############################################################################
#   Everything::Node::textfield
#		Package the implements the base textfield functionality.
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
#		This is called to generate the needed HTML for this textfield
#		form object.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this textfield is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this textfield is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$default - value this object will contain as its initial default.
#			Specify 'AUTO' if you want to use the value of the field this
#			object is bound to, if it is bound
#		$size - the width in characters of the textfield
#		$maxlen - the maximum number of characters this textfield will accept
#
#	Returns
#		The generated HTML for this textfield object
#
sub genObject
{
	my ($this, $query, $bindNode, $field, $name, $default, $size, $maxlen) =
		getParamArray(
		"this, query, bindNode, field, name, default, size, maxlen", @_);

	my $html = $this->SUPER() . "\n";
	
	if($default eq "AUTO")
	{
		$default = "";
		$default = $$bindNode{$field} if($bindNode);
	}

	$html .= $query->textfield(-name => $name, -default => $default,
		-size => $size, -maxlength => $maxlen);
	
	return $html;
}


#############################################################################
# End of package
#############################################################################

1;
