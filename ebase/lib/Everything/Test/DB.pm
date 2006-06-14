sub test_get_nodetype_tables :Test( 7 )
{
	my $self    = shift;
	my $nb      = $self->{nb};
	my $storage = $self->{storage};

	ok( ! $nb->getNodetypeTables(),
		'getNodetypeTables() should return false without type' );

	is_deeply( $nb->getNodetypeTables( 1 ), [ 'nodetype' ],
		'... and should return nodetype given nodetype id' );

	is_deeply( $nb->getNodetypeTables( { node_id => 1  } ), [ 'nodetype' ],
		'... or nodetype node' );

	is_deeply( $nb->getNodetypeTables( { title => 'nodemethod', node_id => 0 }),
		[ 'nodemethod' ],
		'... or should return nodemethod if given nodemethod node' );

	$nb->mock( getRef => sub { $_[1] = $storage } );
	$storage->set_series( getTableArray => [qw( foo bar )] );

	is_deeply( $nb->getNodetypeTables( 'bar' ), [qw( foo bar )],
		'... or calling getTableArray() on promoted node' );

	is_deeply( $nb->getNodetypeTables( 'baz' ), [],
		'... returning nothing if there are no nodetype tables' );

	is_deeply( $nb->getNodetypeTables( 'flaz', 1 ), [ 'node' ],
		'... but adding node if addNode flag is true' );
}
