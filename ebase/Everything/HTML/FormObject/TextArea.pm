package Everything::HTML::FormObject::TextArea;

#############################################################################
#   Everything::HTML::FormObject::TextArea
#		Package the implements the base TextArea functionality.
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
#		This is called to generate the needed HTML for this TextArea
#		form object.
#
#	Parameters
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this TextArea is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that this TextArea is bound to.  If
#			$bindNode is undef, this is ignored.
#		$name - the name of the form object.  ie <input type=text name=$name>
#		$default - value this object will contain as its initial default.
#			Specify 'AUTO' if you want to use the value of the field this
#			object is bound to, if it is bound
#		$cols - number of colums wide the text area should be
#		$rows - number of rows high the text area should be
#		$wrap - either 'off', 'hard', 'physical', 'soft', or 'virtual'.  See
#			HTML 4.0 docs for info.
#
#	Returns
#		The generated HTML for this TextArea object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $default, $cols,
		$rows, $wrap) = getParamArray(
		"query, bindNode, field, name, default, cols, rows, wrap", @_);
	
	$name ||= $field;
	$default ||= 'AUTO';
	$cols ||= 80;
	$rows ||= 20;
	$wrap ||= 'virtual';

	my $html = $this->SUPER::genObject($query, $bindNode, $field, $name) . "\n";
	
	if($default eq "AUTO")
	{
		$default = "";
		$default = $$bindNode{$field} if($bindNode);
	}

	$html .= $query->textarea(-name => $name, 
		-default => $default, -cols => $cols,
		-rows => $rows, -wrap => $wrap);
	
	return $html;
}


#############################################################################
# End of package
#############################################################################

1;

