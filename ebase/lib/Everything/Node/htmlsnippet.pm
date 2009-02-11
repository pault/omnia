=head1 Everything::Node::htmlsnippet

Class representing the htmlsnippet node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::htmlsnippet;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::Parseable', 'Everything::Node::htmlcode';

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype' );

sub get_compilable_field {

    'code'

}

1;
