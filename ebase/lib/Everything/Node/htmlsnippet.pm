=head1 Everything::Node::htmlsnippet

Class representing the htmlsnippet node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::htmlsnippet;

use strict;
use warnings;

use base 'Everything::Node::Parseable', 'Everything::Node::htmlcode';

sub get_compilable_field {

    'code'

}

1;
