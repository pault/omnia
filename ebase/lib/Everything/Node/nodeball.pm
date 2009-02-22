=head1 Everything::Node::nodeball

Class representing the nodeball node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::nodeball;

use Carp;
use Scalar::Util qw/blessed/;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::nodegroup';

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype' );

has vars => ( is => 'rw' );

use Everything::Node::setting;

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

override dbtables => sub
{
	my $self = shift;
	return 'setting', $self->super();
};

=head2 C<insert>

Override the default insert to have the nodeball created with some defaults.

=cut

override insert => sub
{
	my ( $this, $USER ) = @_;

	$this->{vars}     ||= '';
	my $VARS            = $this->getVars();

	# If the node was not inserted with some vars, we need to set some.
	unless ($VARS)
	{
	        # XXX: this must change nodes don't remember the nodebase
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

	my $insert_id = $this->super( $USER );
	return $insert_id if $insert_id;

	Everything::logErrors("Got bad insert id: $insert_id!");
	return 0;
};

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
