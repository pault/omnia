package Everything::Node::theme;

#############################################################################
#   Everything::Node::theme
#       Package the implements the base functionality for theme
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;

#############################################################################
#	Sub
#		getVars
#
#	Purpose
#		All theme nodes join on the setting table.  The vars field in
#		that table contains a string that is an '&' delimited hash.  This
#		function will grab that string and construct a perl hash out of it.
#
#sub getVars 
#{
#	my ($this) = @_;
#
#	return $this->getHash("vars");
#}


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
#sub setVars
#{
#	my ($this, $vars, $USER) = @_;
#
#	$this->setHash($vars, $USER, "vars");
#}


#############################################################################
#	
#sub fieldToXML
#{
#	Everything::Node::setting::fieldToXML(@_);
#}


#############################################################################
# End of package
#############################################################################

1;

