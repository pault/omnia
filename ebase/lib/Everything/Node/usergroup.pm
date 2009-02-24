=head1 Everything::Node::usergroup

Class representing the usergroup node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::usergroup;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::nodegroup';

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype',
    default => sub {
        Everything::Node::nodetype->new(
            Everything::NodetypeMetaData->default_data );
    } );

sub conflictsWith { 0 }

# usergroups are considered part of permissions, and therefore cannot be
# updated from a nodeball
sub updateFromImport { 0 }

1;
