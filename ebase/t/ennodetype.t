#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
	$INC{'Everything/Node/node.pm'} = 
		$INC{'Everything/Security.pm'} = 1;
}

use FakeNode;
use Test::More tests => 47;

use_ok( 'Everything::Node::nodetype' );

use vars qw( $AUTOLOAD );
my $node = FakeNode->new();

# construct()
$node->{node_id} = $node->{extends_nodetype} = 0;
$node->{sqltable} = 'foo,bar,baz';

ok( construct($node), 
	'construct() should always succeed (unless it dies)' );
is( $node->{_calls}[-1][0], 'SUPER', '... should call SUPER()' );
ok( ref $node->{tableArray} eq 'ARRAY', 
	'... should store necessary tables as array ref in "tableArray" field' );

$node->{_calls} = [];
$node->{node_id} = 1;
$node->{DB} = $node->{dbh} = $node;
$node->{_subs} = {
	execute				=> [ 1 ],
	prepare_cached		=> [ $node ],
	fetchrow_hashref	=> [ undef ],
};

construct($node);
is( $node->{type}, $node, '... should set node number 1 type to itself' );
is( join(' ', @{ $node->{_calls}[1] }), 
	"sqlSelect node_id node title='node' && type_nodetype=1", 
	'... should fetch the "node" node if node_id is 1' );
like( join(' ', @{ $node->{_calls}[2] }), 
	qr/^prepare.+select.+from nodetype.+nodetype_id=node_id.+nodetype_id=/,
	'... and fetch its nodetype data' );
is( $node->{_calls}[4][0], 'fetchrow_hashref', 
	'... should populate nodetype node with nodetype data' );

my @fields =
	qw( sqltable maxrevisions canworkspace grouptable defaultgroup_usergroup ); 
@$node{@fields} = ('') x @fields;

foreach my $class (qw( author group guest other )) {
	my @classfields = ("default${class}access", "default${class}_permission");
	push @fields, @classfields;
	@$node{@classfields} = (-1, -1);
}

$node->{extends_nodetype} = $node->{node_id} = 6;

my $parent = { map { $_ => $_, "derived_$_" => $_ } @fields };
$parent->{derived_defaultguestaccess} = 100;
$node->{defaultguestaccess} = 1;
$parent->{derived_sqltable} = 'boo,far';

$node->{_subs} = {
	getNode => [ $parent ],
};

my $ip;
{
	local *Everything::Security::inheritPermissions;
	*Everything::Security::inheritPermissions = sub {
		$ip = join(' ', @_);
	};

	construct($node);
}
is( join(' ', @{ $node->{_calls}[-1] }), 'getNode 6',
	'... should fetch parent nodetype data, if necessary' );
is( $node->{derived_grouptable}, 'grouptable',
	'... should copy derived fields if they are inherited' );

# misleading, I know...
is( $node->{defaultgroupaccess}, -1,
	'... but should not copy other fields' );
is( $ip, '1 100', '... should call inheritPermissions() for permission fields');
is( $node->{derived_sqltable}, 'boo,far', 
	'... should add sqltable fields to the list' );
is( $node->{derived_grouptable}, 'grouptable',
	'... should use parent grouptable if none more specific exists' );

# destruct()
$node->{tableArray} = 1;
destruct($node);
ok( !exists $node->{tableArray}, 'destruct() should remove "tableArray" field');

# insert()
$node->{_calls} = [];
$node->{_subs}{getType} = [ { node_id => 11 }, { node_id => 12 }, 
	{ node_id => 11 } ];

delete $node->{extends_nodetype};
insert($node);
is( $node->{_calls}[1][0], 'SUPER', 'insert() should call SUPER()' );
is( join(' ', @{ $node->{_calls}[-2] }), 'getType node',
	'... should default to extending "node" if no parent is provided' );

$node->{extends_nodetype} = 0;
insert($node);
is( $node->{extends_nodetype}, 12, '... or if the parent is 0' );

# make it extend itself, should not work
$node->{type_nodetype} = 12;
insert($node);
isnt( $node->{extends_nodetype}, 12,
	'... and should not be allowed to extend itself' );

# update()
$node->{_subs}{SUPER} = [ undef, 47 ];
update($node);
is( $node->{_calls}[-1][0], 'SUPER', 'update() should call SUPER()' );

$node->{cache} = $node;
my $result = update($node);
is( $result, 47, '... and return the results' );
is( $node->{_calls}[-1][0], 'flushCacheGlobal',
	'... and flush the global cache, if SUPER() is successful' );

# getTableArray()
$node->{tableArray} = [ 1 .. 4 ];
$result = getTableArray($node);
is( ref $result, 'ARRAY', 
	'getTableArray() should return array ref to "tableArray" field' );
is( scalar @$result, 4, '... and should contain all items' );
ok( ! grep({ $_ eq 'node' } @$result),
	'... should not provide "node" table with no arguments' );
is( getTableArray($node, 1)->[-1], 'node',
	'... but should happily provide it with $nodeTable set to true' );

# getDefaultTypePermissions()
is( getDefaultTypePermissions($node, 'author'),
	$node->{derived_defaultauthoraccess},
	'getDefaultTypePermissions() should return derived permissions for class' );
ok( ! getDefaultTypePermissions($node, 'fakefield'),
	'... should return false if field does not exist' );
ok( ! exists $node->{derived_defaultfakefieldaccess},
	'... and should not autovivify bad field' );

# getParentType()
$node->{_subs}{getType} = [ 88 ];
$node->{extends_nodetype} = 77;
$result = getParentType($node);
is( join(' ', @{ $node->{_calls}[-1] }), 'getType 77',
	'getParentType() should get parent type from the database, if it exists' );
is( $result, 88, '... returning it' );

$node->{extends_nodetype} = 0;
is( getParentType($node), undef,
	'... but should return false if it fails (underived nodetype)' );

# hasTypeAccess()
$node->{_subs}{getNode} = [ $node ];
hasTypeAccess($node, 'user', 'modes');
is( join(' ', @{ $node->{_calls}[-2] }), 
	"getNode dummy_access_node $node create force",
	'hasTypeAccess() should create dummy node with no new permissions' );
is( join(' ', @{ $node->{_calls}[-1] }), 'hasAccess user modes',
	'... and should call hasAccess() to find permissions' );

# isGroupType()
is( isGroupType($node), $node->{derived_grouptable},
	'isGroupType() should return "derived_grouptable" if it exists' );
delete $node->{derived_grouptable},
is( isGroupType($node), undef, '... and false if it does not' );

# derivesFrom()
$node->{_subs} = {
	getType => [ 0, { type_nodetype => 2 }, 
		{ type_nodetype => 1, node_id => 88 }, 
		{ type_nodetype => 1, node_id => 99 }
	],
	getParentType => [ $node ],
};

$result = derivesFrom($node, 'foo');
is( $node->{_calls}[-1][0], 'getType',
	'derivesFrom() should find the type of the first parameter' );
is( $result, 0, '... and should return 0 unless it exists' );

is( derivesFrom($node, 'bar'), 0, '... or if it is not a nodetype node' );

$node->{node_id} = 77;
my $gpt = 0;
{
	local *FakeNode::getParentType;
	*FakeNode::getParentType = sub {
		return if $gpt;
		$gpt = 1;
		$node->{node_id} = 88;
		return $node;
	};
	$result = derivesFrom($node, 'theboatashore');
}
ok( $gpt, '... and should walk up hierarchy with getParentType() as needed' );
is( $result, 1, '... returning true if the nodes are related' );
is( derivesFrom($node, ''), 0, '... and false otherwise' );

# getNodeKeepKeys()
$node->{_calls} = [];
$node->{_subs}{SUPER} = [{ foo => 1 }]; 

$result = getNodeKeepKeys($node);
is( $node->{_calls}[0][0], 'SUPER', 'getNodeKeepKeys() should call SUPER()' );
is( ref $result, 'HASH', '... and should return a hash reference' );
is( scalar grep(/default.+access/, keys %$result), 4,
	'... and should save class access keys' );
is( $result->{defaultgroup_usergroup}, 1, '... and the default usergroup key' );
is( scalar grep(/default.+permission/, keys %$result), 4,
	'... and default class permission keys' );

sub AUTOLOAD {
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	if (defined &{ "Everything::Node::nodetype::$AUTOLOAD" }) {
		*{ $AUTOLOAD } = \&{ "Everything::Node::nodetype::$AUTOLOAD" };
		goto &{ "Everything::Node::nodetype::$AUTOLOAD" };
	}
}
