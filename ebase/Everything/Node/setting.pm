package Everything::Node::setting;

#############################################################################
#   Everything::Node::setting
#       Package the implements the base functionality for setting
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything::Node::node;
use Everything::Security;
use Everything::Util;

#############################################################################
sub construct
{
	my ($this) = @_;

	# Just do what our parent does...
	$this->SUPER();
	
	return 1;
}


#############################################################################
sub destruct
{
	my ($this) = @_;

	$this->SUPER();
}


#############################################################################
#	Sub
#		getVars
#
#	Purpose
#		All setting nodes join on the setting table.  The vars field in
#		that table contains a string that is an '&' delimited hash.  This
#		function will grab that string and construct a perl hash out of it.
#
sub getVars 
{
	my ($this) = @_;

	return $this->getHash("vars");
}


#############################################################################
#	Sub
#		setVars
#
#	Purpose
#		This takes a hash of variables and assigns it to the 'vars' of the
#		given node.  If the new vars are different, we will update the
#		node.
#
#	Parameters
#		$varsref - the hashref to get the vars from
#		$USER - The user that is trying to do this (for authorization)
#
#	Returns
#		Nothing
#
sub setVars
{
	my ($this, $vars, $USER) = @_;

	$this->setHash($vars, $USER, "vars");
}


#############################################################################
sub hasVars
{
	return 1;
}


#############################################################################
sub getFieldDatatype
{
	my ($this, $field) = @_;

	if($field eq 'vars')
	{
		return "vars";
	}

	return $this->SUPER();
}


#############################################################################
# End of package
#############################################################################

1;

