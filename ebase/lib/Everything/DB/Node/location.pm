package Everything::DB::Node::location;

use Moose;

extends 'Everything::DB::Node::node';


=head2 C<delete_node>

Overrides the base delete_node so we can move all the nodes that exist in this
location to the parent location.

=cut

override delete_node => sub {
    my ($self, $node ) = @_;

    my $parentLoc = $node->{loc_location};

    my $id = $node->get_node_id;
    my $result = $self->super;

    if ( $result > 0 ) {

        # Set all the nodes that were in this location to be in the
        # parent location... deleting a location does not delete all
        # the nodes inside of it.
        $self->storage->sqlUpdate( "node", { loc_location => $parentLoc },
            "loc_location=$id" );
    }

    return $result;

};
