
=head1 Everything::Node::workspace

Package that implements the base functionality for workspaces 

Copyright 2000 - 2003 Everything Development Inc.

=cut

# Format: tabs = 4 spaces

package Everything::Node::workspace;

use strict;

#############################################################################
sub nuke
{
	my ( $this, $USER ) = @_;

	return 0 unless ( $this->hasAccess( $USER, "d" ) );

	$this->{DB}->sqlDelete( "revision", "inside_workspace=$$this{node_id}" );
	$this->SUPER();

}

#############################################################################
# End of package
#############################################################################

1;
