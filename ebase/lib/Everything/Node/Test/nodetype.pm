package Everything::Node::Test::nodetype;

use strict;
use warnings;

use base 'Everything::Node::Test::node';
use Test::More;
use SUPER;

# XXX - hack for now
*Everything::Node::nodetype::SUPER = \&UNIVERSAL::SUPER;

sub startup :Test( +1 )
{
	my $self = shift;
	$self->SUPER::startup();
	isa_ok( $self->node_class()->new(), 'Everything::Node::node' );
}

sub test_dbtables :Test( 2 )
{
	my $self   = shift;
	my $module = $self->node_class();
	can_ok( $module, 'dbtables' );
	my @tables = $module->dbtables();
	is_deeply( \@tables, [qw( nodetype node )],
		'dbtables() should return node tables' );
}

sub test_construct :Test( 16 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->set_true(qw( SUPER ));
	$db->set_true( 'finish' );

	$node->{node_id}  = $node->{extends_nodetype} = 0;
	$node->{sqltable} = 'foo,bar,baz';

	ok( $node->construct(),
		'construct() should always succeed (unless it dies)' );

	is( $node->next_call(), 'SUPER', '... should call SUPER()' );
	isa_ok( $node->{tableArray}, 'ARRAY',
		'... storing necessary tables in "tableArray" field as something that' );

	$node->{node_id} = 1;
	$db->set_always( sqlSelect => 1 )
	   ->set_always( sqlSelectJoined => $db )
	   ->set_always( fetchrow_hashref => $node );

	@$node{
		qw(
			defaultguest_permission defaultguestaccess defaultgroupaccess
			defaultauthoraccess canworkspace maxrevisions defaultauthor_permission
			defaultgroup_permission defaultgroup_usergroup defaultotheraccess
			defaultother_permission grouptable
			)
		}
		= ('') x 12;

	$node->construct();
	is( $node->{type}, $node, '... should set node number 1 type to itself' );

	my ( $method, $args ) = $db->next_call();
	is( $method, 'sqlSelect', '... fetching a node if the node_id is 1' );
	is( join( '-', @$args ),
		"$db-node_id-node-title='node' AND type_nodetype=1",
		'... with the appropriate parameters' );

	( $method, $args ) = $db->next_call();
	is( $method, 'sqlSelectJoined', '... fetching its nodetype data' );
	like( join( ' ', @$args ), qr/\* nodetype.+nodetype_id=/,
		'... with the appropriate arguments' );
	is( $db->next_call(), 'fetchrow_hashref',
		'... populating nodetype node with nodetype data' );

	my @fields =
		qw( sqltable maxrevisions canworkspace grouptable defaultgroup_usergroup );
	@$node{@fields} = ('') x @fields;

	for my $class (qw( author group guest other ))
	{
		my @classfields = ( "default${class}access", "default${class}_permission" );
		push @fields, @classfields;
		@$node{@classfields} = ( -1, -1 );
	}

	$node->{extends_nodetype} = $node->{node_id} = 6;

	my $parent = { map { $_ => $_, "derived_$_" => $_ } @fields };
	$parent->{derived_defaultguestaccess} = 100;
	$node->{defaultguestaccess}           = 1;
	$parent->{derived_sqltable}           = 'boo,far';

	$db->set_always( getNode => $parent );

	my $ip;
	{
		local *Everything::Security::inheritPermissions;
		*Everything::Security::inheritPermissions = sub {
			$ip = join( ' ', @_ );
		};

		$node->construct();
	}

	( $method, $args ) = $db->next_call(2);
	is( $method, 'getNode', '... fetching nodetype data, if necessary' );
	is( $args->[1], 6, '... for parent' );
	is( $node->{derived_grouptable},
		'grouptable', '... should copy derived fields if they are inherited' );

	# misleading, I know...
	is( $node->{defaultgroupaccess}, -1, '... but should not copy other fields' );
	is( $ip, '1 100',
		'... should call inheritPermissions() for permission fields' );
	is( $node->{derived_sqltable},
		'boo,far', '... should add sqltable fields to the list' );
	is( $node->{derived_grouptable},
		'grouptable',
		'... should use parent grouptable if none more specific exists' );
}

sub test_destruct :Test()
{
	my $self = shift;
	my $node = $self->{node};
	$node->{tableArray} = 1;
	$node->destruct();
	ok( !exists $node->{tableArray},
		'destruct() should remove "tableArray" field' );
}

sub test_insert :Test( +4 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->{extends_nodetype} = 100;
	$node->{type_nodetype}    = 200;
	$self->SUPER::test_insert();
	delete $node->{extends_nodetype};
	$node->{DB} = $db;
	$node->set_true( 'SUPER' );

	$db->set_series( getType => map { { node_id => $_ } } ( 11, 12, 11 ) );

	$node->insert( 'user' );
	my ( $method, $args ) = $db->next_call();
	is( $method, 'getType', 'insert() with no parent should extend a type' );
	is( $args->[1], 'node', '... the node type, by default' );

	$node->{extends_nodetype} = 0;

	$node->insert( 'user' );
	is( $node->{extends_nodetype}, 12, '... or if the parent is 0' );

	# make it extend itself, should not work
	$node->{type_nodetype} = 12;
	$db->{cache}           = $node;

	$node->insert( 'user' );
	isnt( $node->{extends_nodetype}, 12,
		'... and should not be allowed to extend itself' );
}

sub test_insert_access
{
	my $self = shift;
	my $node = $self->{node};
	$node->{extends_nodetype} = 1;
	$node->{type_nodetype}    = 2;
	$self->SUPER::test_insert_access( @_ );
}

sub test_insert_restrict_dupes
{
	my $self = shift;
	my $node = $self->{node};
	$node->{extends_nodetype} = 1;
	$node->{type_nodetype}    = 2;
	$self->SUPER::test_insert_restrict_dupes( @_ );
}

sub test_insert_restrictions
{
	my $self = shift;
	my $node = $self->{node};
	$node->{extends_nodetype} = 1;
	$node->{type_nodetype}    = 2;
	$self->SUPER::test_insert_restrictions( @_ );
}

sub test_update :Test( +3 )
{
	my $self     = shift;
	my $node     = $self->{node};
	my $db       = $self->{mock_db};

	$node->set_true( 'flushCacheGlobal' );
	$self->SUPER::test_update( @_ );

	$db->{cache} = $node;
	$node->set_series( SUPER => undef, 47 );
	$node->set_true( 'flushCacheGlobal' )->clear();

	$node->update();
	is( $node->next_call(), 'SUPER', 'update() should call SUPER()' );

	$node->{cache} = $node;
	is( $node->update(), 47, '... and return the results' );
	is( $node->next_call( 2 ), 'flushCacheGlobal',
		'... flushing the global cache, if SUPER() is successful' );
}

sub test_nuke_access :Test( +0 )
{
	my $self   = shift;
	my $node   = $self->{node};
	my $db     = $self->{mock_db};
	$db->set_series( -getNode => 0 );
	$self->SUPER();
}

sub test_nuke :Test( 4 )
{
	my $self   = shift;
	my $node   = $self->{node};
	my $db     = $self->{mock_db};
	$node->{DB} = $db;
	$db->set_series( getNode => 1 );

	my $result = $node->nuke( 'user' );
	is( $result, 0,
		'nuke() should return false if nodes of this nodetype exist' );

	like( $self->{errors}[0][0], qr/Can't delete.+still exist/,
		'... giving an appropriate error message' );

	$node->set_always( ('SUPER') x 2 );
	$result = $node->nuke( 'user' );
	is( $node->next_call(), 'SUPER',
		'... otherwise calling parent implementation' );
	is( $result, 'SUPER', '... and returning result' );
}

sub test_get_table_array :Test( 4 )
{
	my $self            = shift;
	my $node            = $self->{node};
	$node->{tableArray} = [ 1 .. 4 ];

	my $result = $node->getTableArray();
	is( ref $result, 'ARRAY',
		'getTableArray() should return array ref to "tableArray" field' );
	is( @$result, 4, '... and should contain all items' );
	ok( !grep( { $_ eq 'node' } @$result ),
		'... should not provide "node" table with no arguments' );
	is( $node->getTableArray( 1 )->[-1], 'node',
		'... but should happily provide it with $nodeTable set to true' );
}

sub test_get_default_type_permissions :Test( 3 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->{derived_defaultauthoraccess} = 'hi, i am the author';

	is( $node->getDefaultTypePermissions( 'author' ),
		$node->{derived_defaultauthoraccess},
		'getDefaultTypePermissions() should return derived class permissions' );
	ok( ! $node->getDefaultTypePermissions( 'fakefield' ),
		'... should return false if field does not exist');
	ok( ! exists $node->{derived_defaultfakefieldaccess},
  		'... and should not autovivify bad field' );
}

sub test_get_parent_type :Test( 4 )
{
	my $self   = shift;
	my $node   = $self->{node};
	my $db     = $self->{mock_db};

	$db->set_always( getType => 88 );
	$node->{extends_nodetype} = 77;

	my $result            = $node->getParentType();
	my ( $method, $args ) = $db->next_call();
	is( $method, 'getType',
		'getParentType() should get parent type, if it exists' );
	is( $args->[1], 77, '... with the parent id' );
	is( $result, 88, '... returning it' );

	$node->{extends_nodetype} = 0;
	is( $node->getParentType(), undef,
		'... but should return false if it fails (underived nodetype)' );
}

sub test_has_type_access :Test( 5 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};
	$db->set_always( getNode => $node );
	$node->set_always( hasAccess => 'acc' );

	my $result = $node->hasTypeAccess( 'user', 'modes' );
	my ( $method, $args ) = $db->next_call();
	is( $method, 'getNode', 'hasTypeAccess() should fetch access node' );
	is( join( '-', @$args ), "$db-dummy_access_node-$node-create force",
		'... forcing a dummy nodetype node' );
	( $method, $args ) = $node->next_call();
	is( $method, 'hasAccess', '... checking access on result' );
	is( join( '-', @$args ), "$node-user-modes", '... for user and perms' );
	is( $result, 'acc', '... returning result' );
}

sub test_is_group_type :Test( 2 )
{
	my $self = shift;
	my $node = $self->{node};

	ok( ! $node->isGroupType(), 
		'isGroupType() should return false unless "derived_grouptable" exists');

	$node->{derived_grouptable} = 648;
	is( $node->isGroupType(), 648, 
		'... and should return "derived_grouptable" if it exists' );
}

sub test_derives_from :Test( 6 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};
	$db->set_series(
		getType => 0,
		{ type_nodetype => 2 },
		{ type_nodetype => 1, node_id => 88 },
		{ type_nodetype => 1, node_id => 99 }
	);

	$node->set_always( getParentType => $node );

	my $result = $node->derivesFrom( 'foo' );
	is( $db->next_call(), 'getType',
		'derivesFrom() should find the type of the first parameter' );
	is( $result, 0, '... returning 0 unless it exists' );

	is( $node->derivesFrom( 'bar' ), 0, '... or if it is not a nodetype node' );

	$node->{node_id} = 77;
	my $gpt = 0;
	{
		$node->mock(
			getParentType => sub {
				return if $gpt;
				$gpt = 1;
				$node->{node_id} = 88;
				return $node;
			}
		);
		$result = $node->derivesFrom( 'theboatashore' );
	}
	ok( $gpt, '... should walk up hierarchy with getParentType() as needed' );
	is( $result, 1, '... returning true if the nodes are related' );
	is( $node->derivesFrom( '' ), 0, '... and false otherwise' );
}

sub test_get_node_keep_keys :Test( 5 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->set_always( SUPER => { foo => 1 } );

	my $result = $node->getNodeKeepKeys();
	is( $node->next_call(), 'SUPER', 'getNodeKeepKeys() should call SUPER()' );
	is( ref $result, 'HASH', '... and should return a hash reference' );
	is( grep( /default.+access/, keys %$result ), 4,
		'... and should save class access keys' );
	is( $result->{defaultgroup_usergroup}, 1,
		'... and the default usergroup key' );
	is( grep( /default.+permission/, keys %$result ), 4,
		'... and default class permission keys' );
}

1;
