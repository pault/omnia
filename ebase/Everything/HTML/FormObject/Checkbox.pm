package Everything::HTML::FormObject::Checkbox;

#############################################################################
#   Everything::HTML::FormObject::Checkbox
#		Package the implements the base checkbox functionality.
#
#   Copyright 2001-2003 Everything Development Inc.
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
#			is checked.
#		$uncheched - a string value of what should be set if the checkbox
#			is NOT checked
#		$default - either 1 (checked), 0 (not checked) or "AUTO".  Where AUTO
#			will set it based on whatever the bound node's field value is.
#		$label - a text string that is to be a visible label for the
#			checkbox
#
#	Returns
#		The generated HTML for this checkbox object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $name, $checked, $unchecked,
		$default, $label) = getParamArray(
		"query, bindNode, field, name, checked, unchecked, default, label", @_);
		
	my $CHECK    = '';
	$checked   ||= 1;
	$unchecked ||= 0;
	$default   ||= "AUTO";
	$label     ||= '';

	my $html = $this->SUPER::genObject(
		$query, $bindNode, $field . ":$unchecked", $name) . "\n";

	if ($default eq 'AUTO')
	{
		$CHECK = (ref $bindNode && ($checked eq $bindNode->{ $field })) ? 1 : 0;
	}
	else
	{
		$CHECK = $default;
	}

	$html .= $query->checkbox(-name => $name, -checked => $CHECK,
		-value => $checked, -label => $label);
	
	return $html;
}


#############################################################################
sub cgiUpdate
{
	my ($this, $query, $name, $NODE, $overrideVerify) = @_;
	my $value = $query->param($name);
	my $field = $this->getBindField($query, $name);

	($field, my $unchecked) = split(':', $field);

	# Make sure this is not a restricted field that we cannot update directly.
	return 0 unless $overrideVerify or $NODE->verifyFieldUpdate($field);

	$value ||= $unchecked;
	$NODE->{$field} = $value;

	return 1;
}


#############################################################################
# End of package
#############################################################################

1;
