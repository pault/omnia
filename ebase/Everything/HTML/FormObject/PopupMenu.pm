package Everything::HTML::FormObject::PopupMenu;

#############################################################################
#   Everything::HTML::FormObject::PopupMenu
#		Package the implements the base PopupMenu functionality.
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
#		This is called to generate the needed HTML for this PopupMenu
#		form object.  NOTE!!!! This cannot be called from
#		[{nodeFormObject:...}] style htmlcode.  This is due to the fact
#		that you need to call the addHash/addArray/addType/addGroup
#		functions to populate this menu before calling this.
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this PopupMenu is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this PopupMenu is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$default - value this object will contain as its initial default.
#			Specify 'AUTO' if you want to use the value of the field this
#			object is bound to, if it is bound
#
#	Returns
#		The generated HTML for this PopupMenu object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $default) = getParamArray(
		"query, bindNode, field, name, default", @_);

	my $html = $this->SUPER::genObject(@_) . "\n";
	
	$name ||= $field;
	$default ||= 'AUTO';
	
	if($default eq "AUTO")
	{
		$default = "";
		$default = $$bindNode{$field} if(ref $bindNode);
	}

	$html .= $this->genPopupMenu($query, $name, $default);

	return $html;
}


#############################################################################
# End of package
#############################################################################

1;


