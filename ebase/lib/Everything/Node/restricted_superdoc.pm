
=head1 Everything::Node::restricted_superdoc

Class representing the restricted_superdoc node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::restricted_superdoc;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;

use MooseX::ClassAttribute;
class_has class_nodetype => (
    reader  => 'get_class_nodetype',
    writer  => 'set_class_nodetype',
    isa     => 'Everything::Node::nodetype',
    default => sub {
        Everything::Node::nodetype->new(
            Everything::NodetypeMetaData->default_data );
    }
);

extends 'Everything::Node::superdoc';

1;
