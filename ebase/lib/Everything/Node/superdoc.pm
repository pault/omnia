
=head1 Everything::Node::superdoc

Class representing the superdoc node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::superdoc;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::document';

with 'Everything::Node::Parseable';

sub get_compilable_field { 'doctext' }

1;
