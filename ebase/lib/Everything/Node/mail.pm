=head1 Everything::Node::mail

Class representing the mail node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::mail;

use strict;
use warnings;

use base 'Everything::Node::document';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'mail', $self->SUPER::dbtables();
}
1;
