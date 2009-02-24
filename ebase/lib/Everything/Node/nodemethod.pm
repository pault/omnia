=head 1 Everything::Node::nodemethod

Class representing the nodemethod node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::nodemethod;

use strict;
use warnings;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;

extends 'Everything::Node::node';

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype',
    default => sub {
        Everything::Node::nodetype->new(
            Everything::NodetypeMetaData->default_data );
    } );

has code => ( is => 'rw' );
has supports_nodetype => ( is => 'rw' );

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
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

sub getIdentifyingFields
{
	return ['supports_nodetype'];
}

1;
