=head1 Everything::Node::mail

Class representing the mail node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::mail;

use strict;
use warnings;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::document';

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype' );

has from_address => ( is => 'rw' );

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

override dbtables => sub
{
	my $self = shift;
	return 'mail', $self->super();
};
1;
