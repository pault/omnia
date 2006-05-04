package Everything::Node::Test::nodegroup;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use SUPER;
use Test::More;

*Everything::Node::nodegroup::SUPER = \&UNIVERSAL::SUPER;

sub test_construct :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( selectGroupArray => 'group' );

	$node->construct();
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
		 ->set_always( -SUPER => 101 );

	$node->{group} = 'foo';

	is( $node->insert( 'user2' ), 101,
		'insert() should return node_id if check succeeds' );
	is( $node->{group}, 'foo',
		'... retaining group attribute' );

	my ( $method, $args ) = $node->next_call();
	is( $method, 'updateGroup', '... calling updateGroup()' );
	is( $args->[1], 'user2',    '... with user' );

	$node->unmock( 'SUPER' )
		 ->set_true( -updateGroup );
	$self->SUPER();
}

sub test_update :Test( +3 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( -SUPER => 4 )
		 ->set_true( 'updateGroup' );

	is( $node->update( 8 ), 4,
		'update() should return results of SUPER() call' );

	my ( $method, $args ) = $node->next_call();
	is( $method, 'updateGroup', '... updating the group' );
	is( $args->[1], 8, '... with the provided user' );

	$node->unmock( 'SUPER' )
		 ->set_true( -updateGroup );

	$self->SUPER();
}

sub test_update_from_import :Test( +4 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( -SUPER => 6 )
		 ->set_true( 'updateGroup' );

	is( $node->updateFromImport( { group => 7 }, 'user' ), 6,
		'updateFromImport() should return result of SUPER() call' );

	is( $node->{group},     7,             '... seting group to new group' );

	my ($method, $args) = $node->next_call();
	is( $method,            'updateGroup', '... and updating group' );
	is( $args->[1],         'user',        '... with the user' );

	$node->unmock( 'SUPER' )
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

1;
__END__

	# nuke()
	$node->{node_id} = 7;
	$node->{dbh}     = $node;

	$node->set_always( SUPER => 12 )->set_always( isGroup => 'table' )
		->set_series( hasAccess => ( 1, 0 ) )->set_true('getRef')->clear();

	is( nuke( $node, 'user' ), 12, 'nuke() should return result of SUPER() call' );
	is( $node->next_call(), 'isGroup', '... should fetch group table' );
	is( $node->next_call(), 'getRef',  '... should nodify user parameter' );
	( $method, $args ) = $node->next_call();
	is( $method, 'hasAccess', '... should check for access' );
	is( join( '-', @$args ), "$node-user-d", '... user delete access' );
	( $method, $args ) = $node->next_call();
	is( $method, 'sqlDelete', '... and should delete the node' );
	is( join( '-', @$args ), "$node-table-table_id=7", '... with the proper id' );

	is( $node->next_call(), 'SUPER', '... calling SUPER' );
	ok( !nuke( $node, '' ), '... returning false if user cannot nuke this node' );

	# isGroup()
	$node->{type}{derived_grouptable} = 77;
	is( isGroup($node), 77, 'isGroup() should return derived group table' );

	# inGroupFast()
	$node->{group} = [ 1, 3, 5, 7, 17, 43 ];
	$node->set_series( getId => 17, 44 )->set_true('groupCache')
		->set_always( 'existsInGroupCache', 'cached?' )->clear();

	$result = inGroupFast( $node, 'node!' );
	( $method, $args ) = $node->next_call();
	is( $method,            'getId',      'inGroupFast() should find node_id' );
	is( $args->[1],         'node!',      '... of node' );
	is( $node->next_call(), 'groupCache', '... populating cache' );
	is( $result,            'cached?',    '... returning result of cache lookup' );

	# inGroup()
	ok( !inGroup($node), 'inGroup() should return false if no node is provided' );

	$node->set_always( selectNodegroupFlat => 'flat' )
		->set_always( getId => 'node_id' )->set_series( hasGroupCache => ( 0, 1 ) )
		->set_always( existsInGroupCache => 'cached?' )->clear();

	$result = inGroup( $node, 'foo' );
	( $method, $args ) = $node->next_call();
	is( $method, 'getId', '... should make sure it has a node_id' );
	is( $args->[1], 'foo', '... with the node parameter' );

	( $method, $args ) = $node->next_call();
	is( $method, 'hasGroupCache', "... checking if there's a group cache" );

	( $method, $args ) = $node->next_call();
	is( $method, 'selectNodegroupFlat',
		'... should call selectNodegroupFlat() to get all group members (if not)' );

	( $method, $args ) = $node->next_call();
	is( $method, 'groupCache', '... caching results' );
	is( $args->[1], 'flat', '... with flat nodegroup' );

	( $method, $args ) = $node->next_call();
	is( $method,    'existsInGroupCache', '... checking group cache' );
	is( $args->[1], 'node_id',            '... with node_id' );
	is( $result,    'cached?',            '... returning result' );

	$node->clear();
	inGroup( $node, 'bar' );
	is( $node->next_call(3), 'existsInGroupCache',
		'... not rebuilding cache if it exists' );
	ok( !inGroup(), '.... returning false if no node is provided' );

	# selectNodegroupFlat()
	$node->{flatgroup} = 17;
	is( selectNodegroupFlat($node),
		17, 'selectNodegroupFlat() should return cached group, if it exists' );
	delete $node->{flatgroup};

	my $traversed = { $node->{node_id} => 1, };
	is( selectNodegroupFlat( $node, $traversed ),
		undef, '... or false if it has seen this node before' );

	$traversed = {};
	$node->set_series( getNode => ( $node, undef, $node ) )
		->set_series( isGroup => ( 1, 0 ) )
		->set_always( selectNodegroupFlat => [ 4, 5 ] )->clear();

	$node->{group} = [ 1, 2 ];

	$result = selectNodegroupFlat( $node, $traversed );
	ok(
		exists $traversed->{ $node->{node_id} },
		'... should mark this node as seen'
	);

	( $method, $args ) = $node->next_call();
	is( $method,            'getNode', '... should fetch each node in group' );
	is( $args->[1],         1,         '... by node_id' );
	is( $node->next_call(), 'isGroup', '... checking if node is a group node' );

	( $method, $args ) = $node->next_call();
	is( $method, 'selectNodegroupFlat', '... fetching group nodes' );
	is( $args->[1], $traversed, '... passing traversed hash' );
	is( join( ' ', @$result ), '4 5', '... returning list of contained nodes' );
	is( $node->{flatgroup}, $result, '... and should cache group' );

	# insertIntoGroup()
	ok( !insertIntoGroup($node),
		'insertIntoGroup() should return false unless a user is provided' );
	ok( !insertIntoGroup( $node, 1 ), '... or if no insertables are provided' );

	$node->set_series( hasAccess => ( 0, 1, 1 ) );
	ok(
		!insertIntoGroup( $node, 'user', 1 ),
		'... or if user does not have write access'
	);

	( $method, $args ) = $node->next_call(2);
	is( $method, 'hasAccess', '... so it should check access' );
	is( join( '-', @$args ), "$node-user-w", '... write access for user' );

	$node->set_series( restrict_type => ( [ 1 .. 3 ], [4] ) )
		->set_series( getId => 3, 2, 1, 4 )->clear();

	insertIntoGroup( $node, 'user', 1, 1 );
	( $method, $args ) = $node->next_call(2);

	is( $method, 'restrict_type', '... checking for type restriction on group' );
	isa_ok( $args->[1], 'ARRAY',
		'... allowing an insertion refs that is scalar or' );

	my $count;
	while ( $method = $node->next_call() )
	{
		$count++ if $method eq 'getId';
	}

	is( $count, 3, '... should get node id of insertion' );
	is( join( ' ', @{ $node->{group} } ),
		'1 3 2 1 2', '... should update "group" field' );
	ok( !exists $node->{flatgroup}, '... and delete "flatgroup" field' );
	ok( insertIntoGroup( $node, 'user', 1 ), '... should return true on success' );
	is( join( ' ', @{ $node->{group} } ),
		'1 3 2 1 2 4', '... appending new nodes if no position is given' );

	# removeFromGroup()
	ok( !removeFromGroup($node),
		'removeFromGroup() should return false unless a user is provided' );
	ok( !removeFromGroup( $node, 'user' ),
		'... or if no insertables are provided' );

	$node->set_series( hasAccess => ( 0, 1 ) )->clear();

	ok(
		!removeFromGroup( $node, 6, 'user' ),
		'... or if user does not have write access'
	);
	( $method, $args ) = $node->next_call();
	is( $method, 'hasAccess', '... checking for access' );
	is( join( '-', @$args ), "$node-user-w", '... write access for user' );

	$node->set_always( hasAccess => (1) )->set_always( getId => (6) )->clear();

	$node->{_calls} = [];
	$node->{group}  = [ 3, 6, 9, 12 ];

	$result = removeFromGroup( $node, 6, 'user' );
	( $method, $args ) = $node->next_call(2);
	is( $method, 'getId', '... should get node_id' );
	is( $args->[1], 6, '... of removable node' );

	is( join( ' ', @{ $node->{group} } ),
		'3 9 12', '... should assign new "group" field without removed node' );
	ok( $result, '... should return true on success' );
	ok( !exists $node->{flatgroup}, '... deleting the cached flat group' );
	is( $node->next_call(), 'groupUncache', '... and uncaching group' );

	# replaceGroup()
	$node->set_series( isGroup => ( '', 'table' ) )->set_series( hasAccess => 0, 1 )
		->set_always( restrict_type => 'abc' )->clear();

	$result = replaceGroup( $node, 'replace', 'user' );

	is( $node->next_call(), 'isGroup', 'replaceGroup() should fetch group table' );
	ok( !$result, '... should return false if user does not have write access' );
	( $method, $args ) = $node->next_call();
	is( $method, 'hasAccess', '... checking for access' );
	is( join( '-', @$args ), "$node-user-w", '... write access for user' );

	$node->{group} = $node->{flatgroup} = 123;
	$result = replaceGroup( $node, 'replace', 'user' );

	( $method, $args ) = $node->next_call(3);
	is( $method, 'restrict_type', '... restricting types of new group' );
	isa_ok( $args->[1], 'ARRAY', '... constraining argument to something that ' );
	is( $node->{group}, 'abc',
		'... should replace existing "group" field with new group' );
	ok( !exists $node->{flatgroup}, '... and should delete any "flatgroup" field' );
	is( $node->next_call(), 'groupUncache', '... uncaching group' );
	ok( $result, '... should return true on success' );

	# getNodeKeys()
	$node->set_series( SUPER => { foo => 1 }, { foo => 2 } )->clear();

	$result = getNodeKeys( $node, 1 );
	is( $node->next_call(), 'SUPER',
		'getNodeKeys() should call SUPER() to get parent type keys' );
	isa_ok( $result, 'HASH', '... should return a hash reference of keys' );
	ok( exists $result->{group},
		'... including a group key if the forExport flag is set' );
	ok( !exists getNodeKeys($node)->{group}, '... excluding it otherwise' );

	# fieldToXML()
	$node->set_series( SUPER => ( 5, 6, 7 ) )->set_true('appendChild')->clear();

	$result = fieldToXML( $node, '', '' );
	is( $node->next_call(), 'SUPER',
		'fieldToXML() should just call SUPER() if not handling a group field' );

	is( $result, 5, '... returning the results' );
	{
		local ( *XML::DOM::Element::new, *XML::DOM::Text::new,
			*Everything::Node::nodegroup::genBasicTag );

		my @xd;
		*XML::DOM::Text::new = sub {
			push @xd, [@_];
			return @_;
		};
		*XML::DOM::Element::new = sub {
			push @xd, [@_];
			return $node;
		};

		my @gbt;
		*Everything::Node::nodegroup::genBasicTag = sub {
			push @gbt, [@_];
		};

		$node->{group} = [ 3, 4, 5 ];
		$node->clear();
		$result = fieldToXML( $node, 'doc', 'group', "\r" );

		is(
			join( ' ', @{ $xd[0] } ),
			'XML::DOM::Element doc group',
			'... otherwise, it should create a new DOM group element'
		);

		my $count;
		for ( 1 .. 6 )
		{
			( $method, $args ) = $node->next_call();
			$count++ if $method eq 'appendChild';
		}

		is( $count, 6, '... appending each child as a Text node' );
		is( join( ' ', map { $_->[3] } @gbt ),
			'3 4 5', '... noted with their node_ids' );
		is( $method, 'appendChild', '... and appending the whole thing' );
		is( $result, $node, '... and should return the new element' );
	}

	# xmlTag()
	my $gcn;
	$node->set_always( SUPER => 8 )
		->set_series( getTagName  => '', 'group', 'group' )
		->set_series( getNodeType => 1,  2,       3 )->set_true('insertIntoGroup')
		->clear();

	$result = xmlTag( $node, $node );
	is( $node->next_call(), 'getTagName', 'xmlTag() should get the tag name' );
	is( $node->next_call(), 'SUPER',
		'... calling SUPER() if it is not a group tag' );
	is( $result, 8, '... returning the results' );

	$node->clear();

	{
		local *XML::DOM::TEXT_NODE;
		*XML::DOM::TEXT_NODE = sub { 3 };

		$node->node( getChildNodes => sub { return if $gcn++; return ($node) x 3 }
		);
		local *Everything::XML::parseBasicTag;

		my @parses = (
			{ where => 'where', },
			{
				name => 'me',
				me   => 'node',
			}
		);
		*Everything::XML::parseBasicTag = sub {
			return shift @parses;
		};
		$result = xmlTag( $node, $node );

		is( $gcn, 1, '... but if it is, should get the child nodes' );
		isa_ok( $result, 'ARRAY',
			'... and should return existing fixup nodes in something that' );

		my @inserts;
		while ( ( $method, $args ) = $node->next_call() )
		{
			push @inserts, $args if $method eq 'insertIntoGroup';
		}

		is( scalar @inserts, 2, '... and should skip text nodes' );
		is( $result->[0]{fixBy}, 'nodegroup', '... should parse nodegroup nodes' );
		is( join( ' ', map { $_->[3] } @inserts ),
			'0 1', '... inserting each into the nodegroup in order' );
		is( join( '|', @{ $inserts[0] } ),
			"$node|-1|-1|0", '... as a dummy node if a where clause is provided' );
		is( join( '|', @{ $inserts[1] } ),
			"$node|-1|node|1", '... or by name if a name is provided' );

		ok( !xmlTag( $node, $node ), '... should return nothing with no fixups' );
	}

	# applyXMLFix()
	$node->set_always( SUPER => 14 )->clear();

	my $fix = { fixBy => 'foo' };
	$result = applyXMLFix( $node, $fix );
	is( $node->next_call(), 'SUPER',
		'applyXMLFix() should call SUPER() unless handling a nodegroup node' );
	is( $result, 14, '... returning its results' );

	{
		local *Everything::XML::patchXMLwhere;

		my $pxw;
		*Everything::XML::patchXMLwhere = sub {
			$pxw++;
			return {
				title         => 'title',
				field         => 'field',
				type_nodetype => 'type',
			};
		};

		$node->set_series( getNode => { node_id => 111 }, 0, 0 );

		$fix = {
			fixBy   => 'nodegroup',
			orderby => 1,
		};

		$result = applyXMLFix( $node, $fix );
		ok( $pxw, '... should call patchXMLwhere() to get the right node data' );
		( $method, $args ) = $node->next_call();
		is( $method, 'getNode', '... attemping to get the node' );
		is( $args->[1]{type_nodetype}, 'type', '... with the where hashref' );
		is( $node->{group}[1],
			111, '... replacing dummy node with fixed node on success' );

		$node->{title} = 'title';
		$node->{type}  = { title => 'typetitle' };

		$result = applyXMLFix( $node, $fix, 1 );
		like(
			$errors,
			qr/Unable to find 'title' of type/,
			'... should warn about missing node if error flag is set'
		);

		$errors = '';
		$result = applyXMLFix( $node, $fix );
		is( $errors, '', '... but should not warn without flag' );

		isa_ok( $result, 'HASH', '... should return fixup data if it failed' );
	}

	# clone()
	$node->set_series( SUPER => undef, ($node) x 2 )->set_true('update')->clear();

	$result = clone( $node, 'user' );
	( $method, $args ) = $node->next_call();
	is( $method, 'SUPER', 'clone() should call SUPER()' );
	is( $args->[1], 'user', '... with the user' );
	ok( !$result, '... and should return false unless that succeeded' );

	$node->{group} = 'group';
	$result = clone( $node, 'user' );
	is( $result, $node, '... or the new node if it succeeded' );
	( $method, $args ) = $node->next_call(2);
	is( $method, 'insertIntoGroup', '... inserting the group into the new node' );
	is( join( '-', @$args ), "$node-user-group",
		'... with the user and the group' );
	( $method, $args ) = $node->next_call();
	is( $method, 'update', '... updating the node' );
	is( $args->[1], 'user', '... with the user' );

	delete $node->{group};
	$node->{_calls} = [];
	isnt( $node->{_calls}[1],
		'insertIntoGroup',
		'... but should avoid insert without a group in the parent' );

	# restrict_type()
	{
		local *Everything::Node::nodegroup::getNode;

		my @nodes = ( 0, 1, 2, 1 );
		my @calls;
		*Everything::Node::nodegroup::getNode = sub {
			push @calls, [@_];
			my $nodenum = shift @nodes;
			return $nodenum
				? { restrict_nodetype => $nodenum, type_nodetype => $nodenum }
				: { type => { restrict_nodetype => 1 }, type_nodetype => 0 };
		};

		$node->{type_nodetype} = 6;
		$result = restrict_type( $node, 'group' );

		is( $calls[0][0], 6,
			'restrict_type() should get the appropriate nodetype' );
		is( $result, 'group',
			'... and should return group unchanged if there is no restriction' );

		$result = restrict_type( $node, [ 1 .. 4 ] );
		is( scalar @calls, 6, '... should get each node in group reference' );

		isa_ok( $result, 'ARRAY',
			'... returning an array reference of proper nodes' );

		is( scalar @$result,
			3, '... and should save nodes that are of the proper type' );
		is( $result->[2], 4,
			'... or group nodes that can contain the proper type' );
	}

	# getNodeKeepKeys()
	$node->set_series( SUPER => { keep => 1, me => 1 } )->clear();

	$result = getNodeKeepKeys($node);
	is( $node->next_call(), 'SUPER', 'getNodeKeepKeys() should call SUPER()' );
	isa_ok( $result, 'HASH', '... returning something that' );
	is( scalar keys %$result, 3, '... containing keys from SUPER() and an extra' );
	ok( $result->{group}, '... and one key should be "group"' );

	# conflictsWith()
	$node->{modified} = '';
	ok( !conflictsWith($node),
		'conflictsWith() should return false with no number in "modified" field' );

	$node->{modified} = 7;
	$node->{group}    = [ 1, 4, 6, 8 ];

	$node->set_always( SUPER => 11 )->clear();

	my $group = { group => [ 1, 4, 6 ] };
	is( conflictsWith( $node, $group ),
		1, '... should return true if groups are different sizes' );

	push @{ $group->{group} }, 9;
	is( conflictsWith( $node, $group ),
		1, '... should return true if a node conflicts between the two nodes' );

	$result = conflictsWith( $node, $node );
	is( $node->next_call(), 'SUPER', '... calling SUPER() if that succeeds' );
	is( $result, 11, '... returning the result' );
