package Everything::Node::usergroup;

#############################################################################
#   Everything::Node::usergroup
#       Package the implements the base functionality for usergroup 
#
#   Copyright 2000 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;


sub conflictsWith {
	0;
}
	
sub updateFromImport {
	#usergroups are considered part of permissions, and therefore cannot
	#be updated from a nodeball
	0;
}


#############################################################################
# End of package
#############################################################################

1;
