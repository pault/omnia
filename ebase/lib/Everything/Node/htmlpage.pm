=head1 Everything::Node::htmlpage

Class representing the htmlpage node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::htmlpage;

use strict;
use warnings;

use base 'Everything::Node::node', 'Everything::Node::Parseable';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'htmlpage', $self->SUPER::dbtables();
}

sub get_compilable_field {
    'page';
}

1;
