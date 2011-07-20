
=head 1 Everything::Node::nodemethod

Class representing the nodemethod node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::nodemethod;

use strict;
use warnings;

use Moose;
use MooseX::FollowPBP; 


extends 'Everything::Node::node';

has code              => ( is => 'rw' );
has supports_nodetype => ( is => 'rw' );

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables {
    my $self = shift;
    return 'nodemethod', $self->SUPER::dbtables();
}

=head2 C<getIdentifyingFields>

Nodemethods can have the same title (name of function), but they are for
different types (supports_nodetype).  We want to make sure that when we search
for them, export them, or import them, we can uniquely identify them.

Returns an array ref of field names that would uniquely identify this node.
undef if none (the default title/type fields are sufficient)

=cut

sub getIdentifyingFields {
    return ['supports_nodetype'];
}

1;
