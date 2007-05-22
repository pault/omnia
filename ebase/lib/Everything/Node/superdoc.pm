=head1 Everything::Node::superdoc

Class representing the superdoc node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::superdoc;

use strict;
use warnings;

use base 'Everything::Node::Parseable', 'Everything::Node::document';

sub get_compilable_field { 'doctext' }

1;
