package Everything::HTML::FormObject::HiddenField;

#############################################################################
#   Everything::HTML::FormObject::HiddenField
#		Package the implements the base HiddenField functionality.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;

use Everything::HTML::FormObject;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject");


#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This is called to generate the needed HTML for this HiddenField
#		form object.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this HiddenField is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this HiddenField is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$default - value this object will contain as its initial default.
#			If undef, this will default to what the field of the bindNode is.
#
#	Returns
#		The generated HTML for this HiddenField object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $default) =
		getParamArray("query, bindNode, field, name, default", @_);

	$name ||= $field;
	$default ||= 'AUTO';

	my $html = $this->SUPER::genObject($query, $bindNode, $field, $name) . "\n";
	
	if($default eq "AUTO")
	{
		$default = "";
		$default = $$bindNode{$field} if($bindNode);
	}

	$html .= $query->hidden(-name => $name, -default => $default);
	
	return $html;
}


#############################################################################
# End of package
#############################################################################

1;
