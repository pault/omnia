
=head1 Everything::Node::htmlpage

Package that implements the base htmlpage functionality

Copyright 2000 - 2003 Everything Development Inc.

=cut

package Everything::Node::htmlpage;

#   Format: tabs = 4 spaces

use strict;

=cut


=head2 C<insert>

We need to set up some default settings when a htmlpage is inserted.

=cut

sub insert
{
	my ( $this, $USER ) = @_;

	# If there is no parent container set, we need a default
	unless ( $$this{parent_container} )
	{
		my $GNC =
			$$this{DB}->getNode( "general nodelet container", "container" );
		$$this{parent_container} = $GNC ? $GNC : 0;
	}

	$this->SUPER();
}

#############################################################################
# End of package
#############################################################################

1;
