package Everything::DBNodeSqlRole;

use Moose::Role;

has storage => ( is => 'rw', required => 1 );

=head2

Takes the following arguments

=over

=item * node_id

=item * node_db_data

A hash ref of the items needed to perform a join



=back

Returns a hashref of attribute name => value pairs.

=cut

sub construct_node_data_from_id {



}



sub construct_node_data_from_name {


}

sub construct_node_data_from_hash {


    my ( $self, $NODE ) = @_;
    my $db = $self->storage;
	my $cursor;
	my $DATA;
	my $tables = $db->retrieve_nodetype_tables( $$NODE{type_nodetype} );
	my $firstTable;
	my $tablehash;

	return unless ( $tables && @$tables > 0 );

	$firstTable = pop @$tables;

	foreach my $table (@$tables)
	{
		$$tablehash{$table} = $firstTable . "_id=$table" . "_id";
	}

	$cursor =
		$db->sqlSelectJoined( "*", $firstTable, $tablehash,
		$firstTable . "_id=" . $$NODE{node_id} );

	return 0 unless ( defined $cursor );

	$DATA = $cursor->fetchrow_hashref();
	$cursor->finish();

	@$NODE{ keys %$DATA } = values %$DATA;

	$db->fix_node_keys($NODE);
	return 1;

}

sub delete_node_data {



}


sub update_node_data {




}

sub attribute_names {
    my ( $self, $node ) = @_;

    my $db = self->get_db;


}

1;
