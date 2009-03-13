package Everything::DB::Node::nodegroup;

use Moose;

extends 'Everything::DB::Node::node';


override construct_node_data_from_hash => sub {

    my ( $self, $NODE ) = @_;

    super;
    my $db = $self->storage;

    my $group_table;
    if (  $group_table = $db->retrieve_group_table( $$NODE{type_nodetype} ) ) {
	my $cursor = $db->sqlSelectMany(
					'node_id', $group_table,
					$group_table . "_id=$$NODE{node_id}",
					'ORDER BY orderby'
				       );

	my @group;
	while ( my $nid = $cursor->fetchrow() ) {
	    push @group, $nid;
	}
	$cursor->finish();

	$$NODE{group} = \@group if @group;
    }

    return 1;
};


=head2 group_table

Returns the name of the group table for this nodegroup.

=cut

sub group_table {

    my $self = shift;
    my $storage = $self->storage;
    return $storage->retrieve_group_table( $self->node->get_type_nodetype );

}

1;

__END__
