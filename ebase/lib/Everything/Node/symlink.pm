=head1 Everything::Node::symlink

Class representing the symlink node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::symlink;


use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::node';

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype' );

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'symlink', $self->SUPER::dbtables();
}
1;
