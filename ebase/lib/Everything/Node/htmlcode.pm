
=head1 Everything::Node::htmlcode

Package that implements the base functionality for htmlcode

Copyright 2000 - 2003 Everything Development Inc.

=cut

package Everything::Node::htmlcode;

#   Format: tabs = 4 spaces

use strict;

=head2 C<restrictTitle>

Prevent invalid database names from being created as titles 

=over 4

=item * $node

the node containing a C<title> field to check

=back

Returns true, if the title is allowable, false otherwise.

=cut

sub restrictTitle
{
	my ($this) = @_;
	my $title = $$this{title} or return;

	if ( $title =~ tr/A-Za-z0-9_//c )
	{
		Everything::logErrors(
			'htmlcode name contains invalid characters.
		 	 Only alphanumerics and the underscore are allowed.  No spaces!',
			'', '', ''
		);
		return;
	}

	return 1;
}

#############################################################################
# End of package
#############################################################################

1;
