=head1 Everything::Node::themesetting

Class representing the themesetting node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::themesetting;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype',
    default => sub {
        Everything::Node::nodetype->new(
            Everything::NodetypeMetaData->default_data );
    } );

extends 'Everything::Node::setting';

has parent_theme => ( is => 'rw' );

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

override dbtables => sub
{
	my $self = shift;
	return 'themesetting', $self->super;
};

1;
