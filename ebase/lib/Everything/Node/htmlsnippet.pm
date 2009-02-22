=head1 Everything::Node::htmlsnippet

Class representing the htmlsnippet node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::htmlsnippet;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype' );

extends  'Everything::Node::htmlcode';
with 'Everything::Node::Parseable';

sub get_compilable_field {

    'code'

}

1;
