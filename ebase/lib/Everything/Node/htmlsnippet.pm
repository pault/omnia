
=head1 Everything::Node::htmlsnippet

Class representing the htmlsnippet node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::htmlsnippet;

use Moose;
use MooseX::FollowPBP; 


extends 'Everything::Node::htmlcode';
with 'Everything::Node::Parseable';

sub get_compilable_field {

    'code'

}

1;
