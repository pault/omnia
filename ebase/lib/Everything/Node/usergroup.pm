=head1 Everything::Node::usergroup

Class representing the usergroup node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::usergroup;

use strict;
use warnings;

use base 'Everything::Node::nodegroup';

sub conflictsWith { 0 }

# usergroups are considered part of permissions, and therefore cannot be
# updated from a nodeball
sub updateFromImport { 0 }

1;
