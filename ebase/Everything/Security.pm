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
	my @childperms = split '', $child;
	my @parentperms = split '', $parent;
    my @perms;
	
	foreach my $i (0..@parentperms-1)
	{
		if($childperms[$i] eq "i")
		{
			# We inherit the parent's setting.
			push @perms, $parentperms[$i]
		}
		else
		{
			# use the child setting.
			push @perms, $childperms[$i];
		}
	}

	return (join('', @perms));
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
	return 0 if($modes eq "");
	
	# We remove any allowed permissions from the given modes.  We need to do
	# this dymanically (evaled) because tr/// does not interpret variables.
	# So, we need to create some code on the fly.
	my $dynamic = "\$modes =~ tr/$perms//d;";
	
	eval($dynamic);

	# If our string is empty, the user has all the needed permissions.
	return 1 if($modes eq "");

	return 0;
}


#############################################################################
# End of package
#############################################################################

1;
