=head1 Everything::Node::nodeball

Class representing the nodeball node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::nodeball;

use strict;
use warnings;

use base 'Everything::Node::nodegroup';

use Everything::Node::setting;

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables
{
	my $self = shift;
	return 'setting', $self->SUPER::dbtables();
}

=head2 C<insert>

Override the default insert to have the nodeball created with some defaults.

=cut

sub insert
{
	my ( $this, $USER ) = @_;
	$this->{vars}     ||= '';
	my $VARS            = $this->getVars();

	# If the node was not inserted with some vars, we need to set some.
	unless ($VARS)
	{
		my $user  = $this->{DB}->getNode($USER);
		my $title = 'ROOT';

		$title = $user->{title}
			if $user && $user->isa( 'Everything::Node' );

		$VARS = {
			author      => $title,
			version     => '0.1.1',
			description => 'No description'
		};

		$this->setVars( $VARS, $USER );
	}

	my $insert_id = $this->SUPER( $USER );
	return $insert_id if $insert_id;

	Everything::logErrors("Got bad insert id: $insert_id!");
	return 0;
}

sub getVars
{
	my ($this) = @_;

	return $this->getHash('vars');
}

sub setVars
{
	my ( $this, $vars ) = @_;

	$this->setHash( $vars, 'vars' );
}

sub hasVars { 1 }

1;
