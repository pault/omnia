package Everything::Node::utility;

#############################################################################
#   Everything::Node::utility
#		Package the implements the base utility node functionality.
#		A utility node is one that does not in the database and
#		exists for the sole purpose for methods to be called on it.
#
#   Copyright 2001 Everything Development Inc.
#   Format: tabs = 4 spaces
#
#############################################################################


use strict;


#############################################################################
#	Sub
#		insert
#
#	Purpose
#		This is a utility class object.  It is here just to provide
#		functionality without any data stored in the database.  We
#		never want to be inserted!
#	
sub insert
{
	return 0;
}


#############################################################################
sub update
{
	return 0;
}


#############################################################################
sub nuke
{
	return 0;
}


#############################################################################
#	Sub
#		getNodeKeys
#
#	Purpose
#		We should never be exported, so return no keys.
#
sub getNodeKeys
{
	return {};
}

#############################################################################
# End of package
#############################################################################

1;
