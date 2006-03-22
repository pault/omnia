=head1 Everything::Node::image

Class representing the image node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::image;

use strict;
use warnings;

use base 'Everything::Node::node';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'image', $self->SUPER::dbtables();
}

1;
