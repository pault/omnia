package Everything::Node::nodemethod;

#############################################################################
#   Everything::Node::nodemethod
#	   Package the implements the base nodemethod functionality
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;
use Everything::Node;


#############################################################################
#	Sub
#		getIdentifyingFields
#
#	Purpose
#		Nodemethods can have the same title (name of function), but they
#		are for different types (supports_nodetype).  We want to make sure
#		that when we search for them, export them, or import them, we can
#		uniquely identify them.
#
#	Returns
#		An array ref of field names that would uniquely identify this node.
#		undef if none (the default title/type fields are sufficient)
#
sub getIdentifyingFields
{
	return ['supports_nodetype'];
}

#############################################################################
# End of package
#############################################################################

1;
