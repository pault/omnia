package Everything::HTML::FormObject::RemoveVarCheckbox;

#############################################################################
#   Everything::HTML::FormObject::RemoveVarCheckbox
#		Package the implements the base RemoveVarCheckbox functionality.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything;

use Everything::HTML::FormObject::Checkbox;
use vars qw(@ISA);
@ISA = ("Everything::HTML::FormObject::Checkbox");

#############################################################################
#	Sub
#		genObject
#
#	Purpose
#		This is called to generate the needed HTML for this RemoveVarCheckbox
#		form object.
#
#	Parameters
#		$query - the CGI object we use to generate the HTML
#		$bindNode - a node ref if this checkbox is to be bound to a field
#			on a node.  undef if this item is not bound.
#		$field - the field on the node that the vars are stored
#		$var - the var in the hash to remove
#
#	Returns
#		The generated HTML for this RemoveVarCheckbox object
#
sub genObject
{
	my $this = shift @_;
	my ($query, $bindNode, $field, $var) =
		getParamArray("query, bindNode, field, var", @_);
		
	# Form objects for updating the key/value pairs are < 55.  This way
	# this will get executed after them, guaranteeing that they will
	# be deleted.
	$$this{updateExecuteOrder} = 55;

	my $name = "remove_" . $field . "_" . $var;
	my $html = $this->SUPER::genObject($query, $bindNode,
		$field . ":$var", $name, "remove", "UNCHECKED") . "\n";

	return $html;
}


#############################################################################
sub cgiUpdate
{
	my ($this, $query, $name, $NODE, $overrideVerify) = @_;
	my $param = $query->param($name);

	# We will not be set unless we are checked
	return 0 unless($param);
	
	my $field = $this->getBindField($query, $name);
	my $var;

	($field, $var) = split(':', $field);

	# Make sure this is not a restricted field that we cannot update
	# directly.
	return 0 unless($overrideVerify or $NODE->verifyFieldUpdate($field));

	my $vars = $NODE->getHash($field);
	delete $$vars{$var} if(exists $$vars{$var});
	$NODE->setHash($vars, $field);

	return 1;
}


#############################################################################
# End of package
#############################################################################

1;

