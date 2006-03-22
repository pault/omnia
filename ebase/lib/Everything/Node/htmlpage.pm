=head1 Everything::Node::htmlpage

Class representing the htmlpage node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::htmlpage;

use strict;
use warnings;

use base 'Everything::Node::node';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'htmlpage', $self->SUPER::dbtables();
}

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

1;
