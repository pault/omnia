package Everything::DB::Node::node;

use Moose;

with "Everything::DBNodeSqlRole";

has node => ( is => 'rw' );

sub retrieve_node {

    my ($this, $args ) = @_;
    my ( $nodebase, $node_name, $node_id, $type ) = @{$args}{qw/nodebase title node_id type/};

    my $node_data;

    if ( $node_id ) {
#	$node_data = $nodebase->get_storage->getNodeByIdNew( $node_id );
	$node_data = $nodebase->get_storage->retrieve_node_data( { type => $type, node_id => $node_id });

    } else {
	$node_data = $nodebase->get_storage->retrieve_node_data( { type => $type, title => $node_name });


    }

    return unless $node_data;
    return $node_data;


}

sub insert_node {

    my ( $this, $node ) = @_;

    # First, we need to insert the node table row.  This will give us
    # the node id that we need to use.  We need to set up the data
    # that is going to be inserted into the node table.

    my $storage = $this->storage;

    my %tableData;

    foreach ( $storage->getFieldsHash('node', 0 ) )
      {
	  $tableData{$_} = $node->{$_} if exists $node->{$_};
      }

    delete $tableData{node_id};

    $tableData{-createtime} = $storage->now();

    $storage->sqlInsert( 'node', \%tableData );

    # Get the id of the node that we just inserted!
    my $node_id = $storage->lastValue( 'node', 'node_id' );

    # Now go and insert the appropriate rows in the other tables that
    # make up this nodetype;

    my $tableArray = $storage->retrieve_nodetype_tables( $node->get_type_nodetype);

    foreach my $table (@$tableArray)
      {
	  my @fields = $storage->getFieldsHash($table, 0 );

	  my %tableData;
	  $tableData{ $table . "_id" } = $node_id;
	  foreach (@fields)
	    {
		$tableData{$_} = $node->{$_} if exists $node->{$_};
	    }

	  $storage->sqlInsert( $table, \%tableData );
      }

    return $node_id;

}

sub update_node {

    my ( $this, $node ) = @_;

    my $storage = $this->storage;

	# We extract the values from the node for each table that it joins
	# on and update each table individually.

    my $tableArray = $storage->retrieve_nodetype_tables( $node->get_type_nodetype, 1);

	foreach my $table (@$tableArray)
	{
		my %VALUES;

		my @fields = $storage->getFieldsHash( $table, 0 );
		foreach my $field (@fields)
		{
			$VALUES{$field} = $node->{$field} if exists $node->{$field};
		}

		$storage->update_or_insert(
						   {
			table => $table,
                        data => \%VALUES,
			where => "${table}_id = ?",
			bound => [ $node->{node_id} ],
			node_id => $node->getId,
						   }
		);
	}

    return $node->{node_id};
}

1;

__END__
