#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use Test::MockObject;
use Test::More tests => 54;

use vars qw( $AUTOLOAD );

my $package = 'Everything::Node::nodetype';

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	if (my $sub = UNIVERSAL::can( $package, $AUTOLOAD))
	{
		*{ $AUTOLOAD } = $sub;
		goto &$sub;
	}
}

my $mock = Test::MockObject->new();
$mock->fake_module( 'Everything::Node::node' );
$mock->fake_module( 'Everything::Security' );

use_ok( 'Everything::Node::nodetype' ) or exit;;

my ($method, $args, $result);

# construct()
$mock->set_true( 'SUPER' )
	 ->set_true( 'finish' );

$mock->{node_id} = $mock->{extends_nodetype} = 0;
$mock->{sqltable} = 'foo,bar,baz';

ok( construct($mock), 
	'construct() should always succeed (unless it dies)' );
is( $mock->next_call(), 'SUPER', '... should call SUPER()' );
isa_ok( $mock->{tableArray}, 'ARRAY', 
	'... storing necessary tables in "tableArray" field as something that' );

$mock->{node_id} = 1;
$mock->{DB} = $mock->{dbh} = $mock;
$mock->set_always( sqlSelect => 1 )
	 ->set_always( sqlSelectJoined => $mock )
	 ->set_always( fetchrow_hashref => $mock )
	 ->clear();

@$mock{ qw(
	defaultguest_permission defaultguestaccess defaultgroupaccess
	defaultauthoraccess canworkspace maxrevisions defaultauthor_permission
	defaultgroup_permission defaultgroup_usergroup defaultotheraccess
	defaultother_permission grouptable
)} = ( '' ) x 12 ;

construct($mock);
is( $mock->{type}, $mock, '... should set node number 1 type to itself' );

($method, $args) = $mock->next_call( 2 );
is( $method, 'sqlSelect', '... fetching a node if the node_id is 1' );
is( join('-', @$args), "$mock-node_id-node-title='node' && type_nodetype=1", 
	'... with the appropriate parameters' );

($method, $args) = $mock->next_call();
is( $method, 'sqlSelectJoined', '... fetching its nodetype data' );
like( join(' ', @$args), qr/\* nodetype.+nodetype_id=/,
	'... with the appropriate arguments' );
is( $mock->next_call(), 'fetchrow_hashref', 
	'... populating nodetype node with nodetype data' );

my @fields =
	qw( sqltable maxrevisions canworkspace grouptable defaultgroup_usergroup ); 
@$mock{@fields} = ('') x @fields;

foreach my $class (qw( author group guest other )) {
	my @classfields = ("default${class}access", "default${class}_permission");
	push @fields, @classfields;
	@$mock{@classfields} = (-1, -1);
}

$mock->{extends_nodetype} = $mock->{node_id} = 6;

my $parent = { map { $_ => $_, "derived_$_" => $_ } @fields };
$parent->{derived_defaultguestaccess} = 100;
$mock->{defaultguestaccess} = 1;
$parent->{derived_sqltable} = 'boo,far';

$mock->set_always( getNode => $parent );

my $ip;
{
	local *Everything::Security::inheritPermissions;
	*Everything::Security::inheritPermissions = sub {
		$ip = join(' ', @_);
	};

	construct($mock);
}

($method, $args) = $mock->next_call( 3 );
is( $method, 'getNode', '... fetching nodetype data, if necessary' );
is( $args->[1], 6, '... for parent' );
is( $mock->{derived_grouptable}, 'grouptable',
	'... should copy derived fields if they are inherited' );

# misleading, I know...
is( $mock->{defaultgroupaccess}, -1,
	'... but should not copy other fields' );
is( $ip, '1 100', '... should call inheritPermissions() for permission fields');
is( $mock->{derived_sqltable}, 'boo,far', 
	'... should add sqltable fields to the list' );
is( $mock->{derived_grouptable}, 'grouptable',
	'... should use parent grouptable if none more specific exists' );

# destruct()
$mock->{tableArray} = 1;
destruct($mock);
ok( !exists $mock->{tableArray}, 'destruct() should remove "tableArray" field');

# insert()
$mock->set_series( getType => map { {node_id => $_} } (11, 12, 11) )
	 ->clear();

delete $mock->{extends_nodetype};
insert($mock);
is( $mock->call_pos( -1 ), 'SUPER', 'insert() should call SUPER()' );
($method, $args) = $mock->next_call();
is( $method, 'getType', '... with no parent should extend a type' );
is( $args->[1], 'node', '... the node type, by default' );

$mock->{extends_nodetype} = 0;
insert($mock);
is( $mock->{extends_nodetype}, 12, '... or if the parent is 0' );

# make it extend itself, should not work
$mock->{type_nodetype} = 12;
$mock->{DB}{cache} = $mock;

insert($mock);
isnt( $mock->{extends_nodetype}, 12,
	'... and should not be allowed to extend itself' );

# update()
$mock->set_series( SUPER => undef, 47 )
	 ->set_true( 'flushCacheGlobal' )
	 ->clear();
update($mock);
is( $mock->next_call(), 'SUPER', 'update() should call SUPER()' );

$mock->{cache} = $mock;
$result = update($mock);
is( $result, 47, '... and return the results' );
is( $mock->next_call( 2 ), 'flushCacheGlobal',
	'... flushing the global cache, if SUPER() is successful' );

# nuke()

# getTableArray()
$mock->{tableArray} = [ 1 .. 4 ];
$result = getTableArray($mock);
is( ref $result, 'ARRAY', 
	'getTableArray() should return array ref to "tableArray" field' );
is( scalar @$result, 4, '... and should contain all items' );
ok( ! grep({ $_ eq 'node' } @$result),
	'... should not provide "node" table with no arguments' );
is( getTableArray($mock, 1)->[-1], 'node',
	'... but should happily provide it with $mockTable set to true' );

# getDefaultTypePermissions()
is( getDefaultTypePermissions($mock, 'author'),
	$mock->{derived_defaultauthoraccess},
	'getDefaultTypePermissions() should return derived permissions for class' );
ok( ! getDefaultTypePermissions($mock, 'fakefield'),
	'... should return false if field does not exist' );
ok( ! exists $mock->{derived_defaultfakefieldaccess},
	'... and should not autovivify bad field' );

# getParentType()
$mock->set_always( getType => 88 )
	 ->clear();

$mock->{extends_nodetype} = 77;
$result = getParentType($mock);
($method, $args) = $mock->next_call();
is( $method, 'getType',
	'getParentType() should get parent type from the database, if it exists' );
is( $args->[1], 77, '... with the parent id' );
is( $result, 88, '... returning it' );

$mock->{extends_nodetype} = 0;
is( getParentType($mock), undef,
	'... but should return false if it fails (underived nodetype)' );

# hasTypeAccess()
$mock->set_always( getNode   => $mock )
	 ->set_always( hasAccess => 'acc' )
	 ->clear();

hasTypeAccess($mock, 'user', 'modes');
($method, $args) = $mock->next_call();
is( $method, 'getNode', 'hasTypeAccess() should fetch node to check perms' );
is( join('-', @$args), "$mock-dummy_access_node-$mock-create force",
	'... forcing a dummy nodetype node' );
($method, $args) = $mock->next_call();
is( $method, 'hasAccess', '... checking access on result' );
is( join('-', @$args), "$mock-user-modes", '... for user and permissions' );

# isGroupType()
is( isGroupType($mock), $mock->{derived_grouptable},
	'isGroupType() should return "derived_grouptable" if it exists' );
delete $mock->{derived_grouptable},
is( isGroupType($mock), undef, '... and false if it does not' );

# derivesFrom()
$mock->set_series(
		getType => 0,
		{ type_nodetype => 2 }, 
		{ type_nodetype => 1, node_id => 88 }, 
		{ type_nodetype => 1, node_id => 99 }
	 )
	 ->set_always( getParentType => $mock )
	 ->clear();

$result = derivesFrom($mock, 'foo');
is( $mock->next_call(), 'getType',
	'derivesFrom() should find the type of the first parameter' );
is( $result, 0, '... returning 0 unless it exists' );

is( derivesFrom($mock, 'bar'), 0, '... or if it is not a nodetype node' );

$mock->{node_id} = 77;
my $gpt = 0;
{
	$mock->mock( getParentType => sub {
		return if $gpt;
		$gpt = 1;
		$mock->{node_id} = 88;
		return $mock;
	});
	$result = derivesFrom($mock, 'theboatashore');
}
ok( $gpt, '... and should walk up hierarchy with getParentType() as needed' );
is( $result, 1, '... returning true if the nodes are related' );
is( derivesFrom($mock, ''), 0, '... and false otherwise' );

# getNodeKeepKeys()
$mock->set_always( SUPER => { foo => 1 })
	 ->clear();

$result = getNodeKeepKeys($mock);
is( $mock->next_call(), 'SUPER', 'getNodeKeepKeys() should call SUPER()' );
is( ref $result, 'HASH', '... and should return a hash reference' );
is( scalar grep(/default.+access/, keys %$result), 4,
	'... and should save class access keys' );
is( $result->{defaultgroup_usergroup}, 1, '... and the default usergroup key' );
is( scalar grep(/default.+permission/, keys %$result), 4,
	'... and default class permission keys' );
