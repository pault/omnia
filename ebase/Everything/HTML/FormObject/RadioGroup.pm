package Everything::HTML::FormObject::RadioGroup;

#############################################################################
#   Everything::HTML::FormObject::RadioGroup
#		Package the implements the base RadioGroup functionality.
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
#		This is called to generate the needed HTML for this RadioGroup
#		form object.  NOTE!!!! This cannot be called from
#		[{nodeFormObject:...}] style htmlcode.  You need to set this
#		up by calling the various add() functions (see FormMenu.pm)
#
#	Parameters
#		Can be passed as either -paramname => value, or an array of 
#		values of the following order:
#
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this RadioGroup is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this RadioGroup is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$default - value this object will contain as its initial default.
#			Specify 'AUTO' if you want to use the value of the field this
#			object is bound to, if it is bound
#		$vertical - if true, it will format the radio buttons vertically
#			by placing a <br> between each one.
#
#	Returns
#		The generated HTML for this RadioGroup object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $default, $vertical) =
		getParamArray(
		"query, bindNode, field, name, default, vertical", @_);

	my $html = $this->SUPER::genObject(@_) . "\n";
	
	if($default eq "AUTO")
	{
		$default = "";
		$default = $$bindNode{$field} if(ref $bindNode);
	}

	my $values = $this->getValuesArray();
	my $labels = $this->getLabelsHash();
	my @buttons = $query->radio_group(-name => $name, -default => $default,
		-values => $values, -labels => $labels);

	if($vertical)
	{
		$html .= join("<br>\n", @buttons);
	}
	else
	{
		$html .= join("\n", @buttons);
	}
	
	return $html;
}


#############################################################################
# End of package
#############################################################################

1;

