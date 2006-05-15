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

	return unless $this->SUPER( $USER );

	$this->{DB}->sqlDelete( 'revision', "inside_workspace=$this->{node_id}" );

	return 1;
}

1;
