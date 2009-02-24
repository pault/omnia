=head1 Everything::Node::theme

Class representing the theme node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::theme;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::nodeball';

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype',
    default => sub {
        Everything::Node::nodetype->new(
            Everything::NodetypeMetaData->default_data );
    } );

1;
