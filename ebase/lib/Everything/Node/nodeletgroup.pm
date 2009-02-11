=head1 Everything::Node::nodeletgroup

Class representing the nodeletgroup node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::nodeletgroup;

use strict;
use warnings;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::nodegroup';

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype' );

1;
