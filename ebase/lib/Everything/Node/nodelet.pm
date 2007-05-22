=head1 Everything::Node::nodelet

Class representing the nodelet node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::nodelet;

use strict;
use warnings;

use base 'Everything::Node::Parseable', 'Everything::Node::node';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'nodelet', $self->SUPER::dbtables();
}

=head2 C<insert>

We need to set up some default settings when a nodelet is inserted.

=cut

sub insert
{
	my ( $this, $USER ) = @_;

	my $GNC = $this->{DB}->getNode( "general nodelet container", "container" );

	# If this gets set to something inappropriate, we can have some
	# infinite container loops.
	$this->{parent_container} = $GNC ? $GNC->{node_id} : 0;
	$this->SUPER( $USER );
}

=head2 C<getNodeKeys>

This removes the nltext parameter, as it is used in caching and will be invalid
when moving to another system or nodeball

=cut

sub getNodeKeys
{
	my ( $this, $forExport ) = @_;

	my $keys = $this->SUPER($forExport);
	delete $keys->{nltext} if $forExport;

	return $keys;
}

sub get_compilable_field {
    'nlcode';
}

1;
