=head1 Everything::Node::usergroup

Package that implements the base functionality for usergroup 

Copyright 2000 - 2003 Everything Development Inc.

=cut

# Format: tabs = 4 spaces

package Everything::Node::usergroup;

use strict;

sub conflictsWith { 0 }
	
# usergroups are considered part of permissions, and therefore cannot be
# updated from a nodeball
sub updateFromImport { 0 }

#############################################################################
# End of package
#############################################################################

1;
