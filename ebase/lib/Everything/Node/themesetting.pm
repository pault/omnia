=head1 Everything::Node::themesetting

Class representing the themesetting node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::themesetting;

use strict;
use warnings;

use base 'Everything::Node::setting';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'themesetting', $self->SUPER::dbtables();
}
1;
