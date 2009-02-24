=head1 Everything::Node::opcode

Class representing the opcode node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::opcode;


use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;

extends 'Everything::Node::htmlcode';

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype',
    default => sub {
        Everything::Node::nodetype->new(
            Everything::NodetypeMetaData->default_data );
    } );

1;
