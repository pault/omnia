=head1 Everything::Node::document

Class representing the document node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::document;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::node';

has doctext => ( is => 'rw' );

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

override dbtables => sub
{
	my $self = shift;
	return 'document', $self->super;
};

1;
