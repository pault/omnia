=head1 Everything::Node::container

Class representing the container node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::container;

use strict;
use warnings;

use base 'Everything::Node::node';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'container', $self->SUPER::dbtables();
}

1;
