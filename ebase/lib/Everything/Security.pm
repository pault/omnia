
=head1 Everything::Security

Support functions for Security and permissions

Copyright 2000 - 2003 Everything Development Corp.

=cut

package Everything::Security;

#	Format: tabs = 4 spaces

use strict;

=cut


=head2 C<inheritPermissions>

This is just a utility function that takes two strings and combines them in a
way such that any 'i' (inherit) flags in the child permissions get over written
by the corresponding parent permission.

=over 4

=item * $child

the child permissions

=item * $parent

the parent permissions

=back

Returns a string that contains the merged

=cut

sub inheritPermissions
{
	my ( $child, $parent ) = @_;

	unless ( length $child == length $parent )
	{
		Everything::logErrors("Permission length mismatch!");
		return;
	}

	my $pos;
	while ( ( $pos = index( $child, 'i' ) ) > -1 )
	{
		substr( $child, $pos, 1, substr( $parent, $pos, 1 ) );
	}
	return $child;
}

=cut


=head2 C<checkPermissions>

Given the permissions that a user has, and the permissions that they need,
return true or false indicating that they have or do not have the needed
permissions.

=over 4

=item * $perms

the permissions that the user has

=item * $modes

the permissions that they need

=back

Returns 1 (true) if the user has all the needed permissions.  0 (false)
otherwise

=cut

sub checkPermissions
{
	my ( $perms, $modes ) = @_;

	# if no modes are passed in, we have nothing to check against.  For
	# security purposes, we will return false.  We need something to check!
	return 0 unless defined $perms and $perms and defined $modes and $modes;

	# We remove any allowed permissions from the given modes.
	$modes =~ s/[$perms]//g;

	return $modes ? 0 : 1;
}

#############################################################################
# End of package
#############################################################################

1;
