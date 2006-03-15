=head1 Everything::Node::workspace

Class representing the workspace node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::workspace;

use strict;
use warnings;

use base 'Everything::Node::setting';

sub nuke
{
	my ( $this, $USER ) = @_;

	return 0 unless ( $this->hasAccess( $USER, "d" ) );

	$this->{DB}->sqlDelete( "revision", "inside_workspace=$$this{node_id}" );
	$this->SUPER();

}

1;
