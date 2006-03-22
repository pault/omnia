=head1 Everything::Node::htmlcode

Class representing the htmlcode node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::htmlcode;

use strict;
use warnings;

use base 'Everything::Node::node';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'htmlcode', $self->SUPER::dbtables();
}

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

1;
