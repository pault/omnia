=head1 Everything::Node::nodelet

Class representing the nodelet node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::nodelet;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;

use MooseX::ClassAttribute;
class_has class_nodetype => ( reader => 'get_class_nodetype', writer => 'set_class_nodetype', isa => 'Everything::Node::nodetype',
    default => sub {
        Everything::Node::nodetype->new(
            Everything::NodetypeMetaData->default_data );
    } );

extends 'Everything::Node::node';

has $_ => ( is => 'rw' ) foreach qw/mini_nodelet nlcode parent_container updateinterval nltext/;

with 'Everything::Node::Parseable';


=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

override dbtables => sub
{
	my $self = shift;
	return 'nodelet', $self->super;
};

=head2 C<insert>

We need to set up some default settings when a nodelet is inserted.

=cut

override insert => sub
{
	my ( $this, $USER ) = @_;

	my $GNC = $this->{DB}->getNode( "general nodelet container", "container" );

	# If this gets set to something inappropriate, we can have some
	# infinite container loops.
	$this->{parent_container} = $GNC ? $GNC->{node_id} : 0;
	$this->super( $USER );
};

=head2 C<getNodeKeys>

This removes the nltext parameter, as it is used in caching and will be invalid
when moving to another system or nodeball

=cut

override getNodeKeys => sub
{
	my ( $this, $forExport ) = @_;

	my $keys = $this->super($forExport);
	delete $keys->{nltext} if $forExport;

	return $keys;
};

sub get_compilable_field {
    'nlcode';
}

1;
