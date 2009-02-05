package Everything::Node::Test::nodegroup;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use Test::More;
use SUPER;

sub test_construct :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( selectGroupArray => 'group' );

	$node->BUILD();
	is( $node->{group}, 'group',
		'construct() should set "group" field to group array' );
}

sub test_select_group_array :Test( 8 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->{node_id} = 111;
	$node->set_always( isGroup => 'grouptable' );
	$db->set_true( qw( createGroupTable finish ))
	   ->set_series( sqlSelectMany => undef, $db )
	   ->set_series( fetchrow => ( 1, 7, 9 ) );

	my $result = $node->selectGroupArray();
	my ( $method, $args ) = $node->next_call();
	is( $method, 'isGroup',
		'selectGroupArray() should call isGroup() to get group table' );
	is( $result, undef, '... returning if selection fails' );

	$result = $node->selectGroupArray();

	isa_ok( $result, 'ARRAY',
		'... and should return contained nodes in something that' );
	is( @$result, 3, '... ALL of the nodes' );

	( $method, $args ) = $db->next_call();
	is( $method, 'createGroupTable', '... ensuring that the table exists' );
	is( $args->[1], 'grouptable', '... with the correct name' );

	( $method, $args ) = $db->next_call();
	is( $method, 'sqlSelectMany',
		'... and should select nodes from the group table' );
	is( join( '-', @$args ),
		"$db-node_id-grouptable-grouptable_id=111-ORDER BY orderby",
		'... with the appropriate arguments' );
}

sub test_destruct :Test( +2 )
{
	my $self = shift;
	my $node = $self->{node};

	$self->SUPER();

	$node->{group} = $node->{flatgroup} = 1;
	$node->destruct();

	ok( ! exists $node->{group},     '... should delete the "group" variable' );
	ok( ! exists $node->{flatgroup}, '... and the "flatgroup" variable' );
}

sub test_insert :Test( +4 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->set_true( 'updateGroup' )
		 ->set_always( -super => 101 );

	$node->{group} = 'foo';

	is( $node->insert( 'user2' ), 101,
		'insert() should return node_id if check succeeds' );
	is( $node->{group}, 'foo',
		'... retaining group attribute' );

	my ( $method, $args ) = $node->next_call();
	is( $method, 'updateGroup', '... calling updateGroup()' );
	is( $args->[1], 'user2',    '... with user' );

	$node->unmock( 'super' )
		 ->set_true( -updateGroup );
	$self->SUPER();
}

sub test_update :Test( +3 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( -super => 4 )
		 ->set_true( 'updateGroup' );

	is( $node->update( 8 ), 4,
		'update() should return results of SUPER() call' );

	my ( $method, $args ) = $node->next_call();
	is( $method, 'updateGroup', '... updating the group' );
	is( $args->[1], 8, '... with the provided user' );

	$node->unmock( 'super' )
		 ->set_true( -updateGroup );

	$self->SUPER();
}

sub test_update_from_import :Test( +4 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( -super => 6 )
		 ->set_true( 'updateGroup' );

	is( $node->updateFromImport( { group => 7 }, 'user' ), 6,
		'updateFromImport() should return result of SUPER() call' );

	is( $node->{group},     7,             '... seting group to new group' );

	my ($method, $args) = $node->next_call();
	is( $method,            'updateGroup', '... and updating group' );
	is( $args->[1],         'user',        '... with the user' );

	$node->unmock( 'super' )
		 ->set_true( -updateGroup );
	$self->SUPER();
}

sub test_update_group_access :Test( 2 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( hasAccess => 0 );

	ok( ! $node->updateGroup(),
		'updateGroup() should return false without user' );
	ok( ! $node->updateGroup( 'user' ),
		'... or if user has no write access' );
}

sub test_update_group :Test( 19 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->set_always( isGroup => 'gtable' )
		 ->set_true( 'hasAccess' )
		 ->mock( restrict_type => sub { $_[1] } )
		 ->set_series( selectGroupArray => ( [ 2, 4, 6, 10 ] ) );

	$db->set_true( qw( sqlSelect sqlInsert sqlUpdate -groupUncache ))
	   ->set_series( -sqlDelete => ( 1, 2, 1, 2 ) );

	$node->{node_id} = 411;
	$node->{group}   = [ 1, 2, 4, 8 ];

	ok( $node->updateGroup( 'user' ),
		'updateGroup() should succeed if user has access' );

	my ( $method, $args ) = $node->next_call(2);
	is( $method, 'restrict_type', '... should restrict group members' );
	is_deeply( $args->[1], [ 1, 2, 4, 8 ],      '... to group' );
	is( $node->next_call(), 'isGroup',          '... fetching group table' );
	is( $node->next_call(), 'selectGroupArray', '... and group node_ids' );

	my %group;
	@group{ @{ $node->{group} } } = ();
	ok( !( exists $group{6} and exists $group{10} ),
		'... deleting nodes that do not exist in new group' );
	is( join( '-', sort keys %group ), '1-2-4-8',
		'... keeping the correct nodes' );
	like( $self->{errors}[0][0], qr/Wrong number of group members deleted!/,
		'... warning if deleting the wrong number of nodes' );

	( $method, $args ) = $db->next_call();

	is( $method, 'sqlSelect', '... selecting max rank if inserting' );
	like( join( '-', @$args ), qr/max\(rank\)-gtable-gtable_id=/,
		'... from proper table' );

	( $method, $args ) = $db->next_call();
	is( $method,               'sqlInsert', '... inserting new nodes' );
	is( $args->[1],            'gtable',    '... into the right table' );
	is( $args->[2]{gtable_id}, 411,         '... for the right group' );
	is( $args->[2]{node_id},   8,           '... and the right node_id' );

	( $method, $args ) = $db->next_call( 13 );
	is( $method,             'sqlUpdate', '... updating each node in group' );
	is( $args->[1],          'gtable',    '... in the group table' );
	is( $args->[2]{orderby}, 3,           '...with new order' );
	like( $args->[3], qr/gtable_id=411.+node_id=8.+rank/,
		'... with the correct arguments' );
	is( join( ' ', @{ $node->{group} } ), '1 2 4 8',
		'... assigning new group to the node' );
}

sub test_nuke :Test( 7 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};
	
	$node->{node_id} = 7;

	$node->set_always( super => 12 )
	     ->set_always( isGroup => 'table' )
		 ->set_true( -hasAccess );
	$db->set_true(qw( getRef sqlDelete ));

	is( $node->nuke( 'user' ), 12,
		'nuke() should return result of SUPER() call' );

	is( $node->next_call(), 'isGroup', '... fetching group table' );
	is( $db->next_call(), 'getRef',  '... and nodifying user parameter' );

	my ( $method, $args ) = $db->next_call();
	is( $method, 'sqlDelete', '... and should delete the node' );
	is( join( '-', @$args ), "$db-table-table_id=7",
		'... with the proper id' );

	( $method, $args )    = $node->next_call();
	is( $method, 'super', '... calling super' );
	is( $args->[1], 'user', '... passing $USER' );
}

sub test_is_group :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->{type}{derived_grouptable} = 77;
	is( $node->isGroup(), 77, 'isGroup() should return derived group table' );
}

sub test_in_group_fast :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->{group} = [ 1, 3, 5, 7, 17, 43 ];
	$db->set_series( getId => 17, 44 );
	$node->set_true('groupCache')
		 ->set_always( 'existsInGroupCache', 'cached?' );

	my $result = $node->inGroupFast( 'node!' );

	my ( $method, $args ) = $db->next_call();
	is( $method,            'getId',   'inGroupFast() should find node_id' );
	is( $args->[1],         'node!',   '... of node' );
	is( $node->next_call(), 'groupCache', '... populating cache' );
	is( $result,            'cached?', '... returning result of cache lookup' );
}

sub test_in_group :Test( 10 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	ok( ! $node->inGroup(),
		'inGroup() should return false with no node provided' );

	$node->set_always( -selectNodegroupFlat => 'flat' )
		 ->set_series( -hasGroupCache => ( 0, 1 ) )
		 ->set_always( existsInGroupCache => 'cached?' )
		 ->set_true( 'groupCache' );
	$db->set_always( getId => 'node_id' );

	my $result = $node->inGroup( 'foo' );
	my ( $method, $args ) = $db->next_call();
	is( $method, 'getId', '... ensuring that it has a node_id' );
	is( $args->[1], 'foo', '... with the node parameter' );

	( $method, $args ) = $node->next_call();
	is( $method, 'groupCache', '... caching results' );
	is( $args->[1], 'flat',    '... with flat nodegroup' );

	( $method, $args ) = $node->next_call();
	is( $method,    'existsInGroupCache', '... checking group cache' );
	is( $args->[1], 'node_id',            '... with node_id' );
	is( $result,    'cached?',            '... returning result' );

	$node->inGroup( 'bar' );
	is( $node->next_call(), 'existsInGroupCache',
		'... not rebuilding cache if it exists' );
	ok( ! $node->inGroup(), '.... returning false if no node is provided' );
}

sub test_select_nodegroup_flat :Test( 10 )
{
	my $self       = shift;
	my $node       = $self->{node};
	my $db         = $self->{mock_db};
	my $group_node = Test::MockObject->new();

	$node->{flatgroup} = 17;
	is( $node->selectNodegroupFlat(), 17,
		'selectNodegroupFlat() should return cached group, if it exists' );

	delete $node->{flatgroup};

	$node->{node_id} = 7;
	my $traversed = { $node->{node_id} => 1, };
	is( $node->selectNodegroupFlat( $traversed ), undef,
		'... or false if it has seen this node before' );

	$traversed = {};
	$db->set_series( getNode => ( $group_node, undef, $group_node ) );
	$group_node->set_always( selectNodegroupFlat => [ 4, 5 ] )
	           ->set_series( isGroup => ( 1, 0 ) );

	$node->{group} = [ 1, 2 ];
	$group_node->clear;

	my $result = $node->selectNodegroupFlat( $traversed );
	ok( exists $traversed->{ $node->{node_id} },
		'... marking this node as seen' );

	my ( $method, $args ) = $db->next_call();
	is( $method,            'getNode', '... fetching each node in group' );
	is( $args->[1],         1,         '... by node_id' );
	is( $group_node->next_call(), 'isGroup',
		'... checking if node is a group node' );

	( $method, $args ) = $group_node->next_call();
	is( $method, 'selectNodegroupFlat', '... fetching group nodes' );
	is( $args->[1], $traversed, '... passing traversed hash' );
	is( join( ' ', @$result ), "$group_node 4 5", '... returning list of contained nodes' );
	is( $node->{flatgroup}, $result, '... and caching group' );
}

sub test_insert_into_group :Test( 11 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->{group} = [ 1, 2 ];
	$node->set_true( 'groupUncache' );

	ok( ! $node->insertIntoGroup(),
		'insertIntoGroup() should return false without a user' );
	ok( ! $node->insertIntoGroup( 1 ), '... or with no insertables' );

	$node->set_series( -hasAccess => ( 0, 1, 1 ) );
	ok( ! $node->insertIntoGroup( 'user', 1 ),
		'... or if user lacks write access' );

	$node->set_series( restrict_type => ( [ 1 .. 3 ], [4] ) );
	$db->set_series( getId => 3, 2, 1, 4 );

	$node->insertIntoGroup( 'user', 1, 1 );
	my ( $method, $args ) = $node->next_call();

	is( $method, 'restrict_type', '... checking for group type restriction' );
	isa_ok( $args->[1], 'ARRAY',
		'... allowing an insertion refs that is scalar or' );

	my $count;
	while ( $method = $db->next_call() )
	{
		$count++ if $method eq 'getId';
	}

	is( $count, 3, '... getting node id of insertion' );
	is( join( ' ', @{ $node->{group} } ),
		'1 3 2 1 2', '... updating "group" field' );
	ok( ! exists $node->{flatgroup}, '... and deleting "flatgroup" field' );
	ok( $node->insertIntoGroup( 'user', 1 ), '... returning true on success' );
	is( join( ' ', @{ $node->{group} } ), '1 3 2 1 2 4',
		'... appending new nodes with no position given' );
	is( $node->next_call(), 'groupUncache', '... and clearing cache' );
}

sub test_remove_from_group :Test( 7 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	ok( ! $node->removeFromGroup(),
		'removeFromGroup() should return false without a user' );
	ok( ! $node->removeFromGroup( 'user' ), '... or without insertables' );

	$node->set_series( -hasAccess => 0, 1 )
		 ->set_true( 'groupUncache' );

	ok( ! $node->removeFromGroup( 6, 'user' ),
		'... or if user lacks write access' );

	$db->set_always( getId => 6 );

	$node->{group}  = [ 3, 6, 9, 12 ];

	my $result = $node->removeFromGroup( 6, 'user' );

	is( join( ' ', @{ $node->{group} } ), '3 9 12',
		'... assign new "group" field without removed node' );
	ok( $result, '... returning true on success' );
	ok( ! exists $node->{flatgroup}, '... deleting the cached flat group' );
	is( $node->next_call(), 'groupUncache', '... and uncaching group' );
}

sub test_replace_group :Test( 8 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->set_series( isGroup => ( '', 'table' ) )
	     ->set_series( -hasAccess => 0, 1 )
		 ->set_always( restrict_type => 'abc' )
		 ->set_true( 'groupUncache' );

	my $result = $node->replaceGroup( 'replace', 'user' );

	is( $node->next_call(), 'isGroup',
		'replaceGroup() should fetch group table' );
	ok( ! $result, '... returning false unless user has write access' );

	$node->{group} = $node->{flatgroup} = 123;
	$result = $node->replaceGroup( 'replace', 'user' );

	my ( $method, $args ) = $node->next_call(2);
	is( $method, 'restrict_type', '... restricting types of new group' );
	isa_ok( $args->[1], 'ARRAY',
		'... constraining argument to something that ' );
	is( $node->{group}, 'abc',
		'... replacing existing "group" field with new group' );
	ok( !exists $node->{flatgroup}, '... and deleting any "flatgroup" field' );
	is( $node->next_call(), 'groupUncache', '... uncaching group' );
	ok( $result, '... returning true on success' );
}

sub test_get_node_keys :Test( 5 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_series( SUPER => { foo => 1 }, { foo => 2 } );

	my $result = $node->getNodeKeys( 1 );
	my ($method, $args) = $node->next_call();

	is( $method, 'SUPER',
		'getNodeKeys() should call SUPER() to get parent type keys' );
	is( $args->[1], 1, '... passing export flag' );

	isa_ok( $result, 'HASH', '... should return a hash reference of keys' );

	ok( exists $result->{group},
		'... including a group key if the forExport flag is set' );
	ok( !exists $node->getNodeKeys()->{group}, '... excluding it otherwise' );
}

sub test_clone :Test( 9 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_series( SUPER => undef, ($node) x 2 )
	      ->set_true(qw( update insertIntoGroup ));

	my $result            = $node->clone( 'user' );
	my ( $method, $args ) = $node->next_call();
	is( $method, 'SUPER', 'clone() should call SUPER()' );
	is( $args->[1], 'user', '... with the user' );
	ok( !$result, '... and should return false unless that succeeded' );

	$node->{group} = 'group';
	$result = $node->clone( 'user' );
	is( $result, $node, '... or the new node if it succeeded' );

	( $method, $args ) = $node->next_call(2);
	is( $method, 'insertIntoGroup',
		'... inserting the group into the new node' );
	is( join( '-', @$args ), "$node-user-group",
		'... with the user and the group' );

	( $method, $args ) = $node->next_call();
	is( $method, 'update', '... updating the node' );
	is( $args->[1], 'user', '... with the user' );

	delete $node->{group};

	$node->clone( 'user' );

	isnt( $node->next_call( 2 ), 'insertIntoGroup',
		'... but should avoid insert without a group in the parent' );
}

sub test_restrict_type :Test( 7 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	my @nodes = ( 0, 1, 2, 1 );
	$db->mock( getNode => sub
	{
		my $nodenum = shift @nodes;
		return $nodenum
			? { restrict_nodetype => $nodenum, type_nodetype => $nodenum }
			: { type => { restrict_nodetype => 1 }, type_nodetype => 0 };
	});

	$node->{type_nodetype} = 6;
	my $result = $node->restrict_type( 'group' );

	my ($method, $args) = $db->next_call();
	is( $method, 'getNode',
		'restrict_type() should get the appropriate nodetype' );
	is( $args->[1], 6, '... by node_id' );
	is( $result, 'group',
		'... returning group unchanged if there is no restriction' );

	$result   = $node->restrict_type( [ 1 .. 4 ] );
	my $count = () = grep
	{
		my $call = $db->next_call() || '';
		$call eq 'getNode'
	} 1 .. 7;

	is( $count, 5, '... fetching each node in group reference' );

	isa_ok( $result, 'ARRAY',
		'... returning an array reference of proper nodes' );

	is( @$result, 3, '... saving nodes of the proper type' );
	is( $result->[2], 4,
		'... or group nodes that can contain the proper type' );
}

sub test_get_node_keep_keys :Test( +4 )
{
	my $self = shift;
	my $node = $self->{node};
	$self->SUPER();

	$node->set_series( SUPER => { keep => 1, me => 1 } );

	my $result = $node->getNodeKeepKeys();
	is( $node->next_call(), 'SUPER', 'getNodeKeepKeys() should call SUPER()' );
	isa_ok( $result, 'HASH', '... returning something that' );
	is( keys %$result, 3, '... containing keys from SUPER() and an extra' );
	ok( $result->{group}, '... and one key should be "group"' );
}

sub test_conflicts_with :Test( 6 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->{modified} = '';
	ok( !$node->conflictsWith(),
		'conflictsWith() should return false lacking "modified" field num' );

	$node->{modified} = 7;
	$node->{group}    = [ 1, 4, 6, 8 ];

	$node->set_always( SUPER => 11 );

	my $group = { group => [ 1, 4, 6 ] };
	is( $node->conflictsWith( $group ), 1,
		'... returing true if groups are different sizes' );

	push @{ $group->{group} }, 9;
	is( $node->conflictsWith( $group ), 1,
		'... returning true if a node conflicts between the two nodes' );

	my $result = $node->conflictsWith( $node );
	my ($method, $args) = $node->next_call();
	is( $method, 'SUPER',  '... calling SUPER() if that succeeds' );
	is( $args->[1], $node, '... passing new node' );

	is( $result, 11, '... returning the result' );
}

1;
