package Everything::Security;

#############################################################################
#	Everything::NodeBase
#		Support functions for Security and permissions
#
#	Copyright 2000 Everything Development Corp.
#	Format: tabs = 4 spaces
#
#############################################################################

use strict;


#############################################################################
#	Sub
#		inheritPermissions
#
#	Purpose
#		This is just a utility function that takes two strings and combines
#		them in a way such that any 'i' (inherit) flags in the child
#		permissions get over written by the corresponding parent permission.
#
#	Parameters
#		$child - the child permissions
#		$parent - the parent permissions
#
#	Returns
#		A string that contains the merged
#
sub inheritPermissions
{
	my ($child, $parent) = @_;

	unless (length $child == length $parent) {
		warn "Permission length mismatch!";
		return;
	}

	my $pos;
	while (($pos = index($child, 'i')) > -1) {
		substr($child, $pos, 1, substr($parent, $pos, 1));
	}
	return $child;
}


#############################################################################
#	Sub
#		checkPermissions
#
#	Purpose
#		Given the permissions that a user has, and the permissions that
#		they need, return true or false indicating that they have or
#		do not have the needed permissions
#
#	Parameters
#		$perms - the permissions that the user has
#		$modes - the permissions that they need
#
#	Returns
#		1 (true) if the user has all the needed permissions.  0 (false)
#		otherwise
#
sub checkPermissions
{
	my ($perms, $modes) = @_;
	
	# if no modes are passed in, we have nothing to check against.  For
	# security purposes, we will return false.  We need something to check!
	return 0 unless (defined $perms and $perms and defined $modes and $modes);
	
	# We remove any allowed permissions from the given modes.
	$modes =~ s/[$perms]//g;

	return $modes ? 0 : 1;
}


#############################################################################
# End of package
#############################################################################

1;
