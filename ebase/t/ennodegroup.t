#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
	@INC{'Everything.pm', 'Everything/XML.pm', 'XML/DOM.pm'} = (1, 1, 1);
}

use vars qw( $AUTOLOAD $errors );

use Test::MockObject;
use Test::More tests => 177;

use_ok( 'Everything::Node::nodegroup' ) or diag "Compile error\n", exit;

sub AUTOLOAD {
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::Node::nodegroup::$AUTOLOAD";
	if (defined &{ $sub }) {
		*{ $AUTOLOAD } = \&{ $sub };
		goto &{ $sub };
	}
}

package Everything;

sub logErrors {
	$main::errors = join(' ', @_);
}

package main;

my $mock = Test::MockObject->new();

# construct()
$mock->set_always( selectGroupArray => 'group' );

construct($mock);
is( $mock->next_call(), 'selectGroupArray',
	'construct() should fetch the contained nodes' );
is( $mock->{group}, 'group', '... and should set "group" field to results' );

# selectGroupArray()
$mock->{node_id} = 111;
$mock->{DB} = $mock;
$mock->set_always( isGroup => 'grouptable' )
     ->set_true( 'createGroupTable' )
	 ->set_series( sqlSelectMany => undef, $mock )
	 ->set_series( fetchrow => ( 1, 7, 9 ) )
	 ->set_true( 'finish' )
	 ->clear();

my $result = selectGroupArray($mock);
my ($method, $args) = $mock->next_call();
is( $method, 'isGroup',
	'selectGroupArray() should call isGroup() to get group table' );
is( $result, undef, '... returning if selection fails' );

$result = selectGroupArray($mock);

isa_ok( $result, 'ARRAY',
	'... and should return contained nodes in something that' );
is( scalar @$result, 3, '... ALL of the nodes' );
($method, $args) = $mock->next_call();
is( $method, 'createGroupTable', '... ensuring that the table exists' );
is( $args->[1], 'grouptable', '... with the correct name' );
($method, $args) = $mock->next_call();
is( $method, 'sqlSelectMany', 
	'... and should select nodes from the group table' );
is( join('-', @$args), 
	"$mock-node_id-grouptable-grouptable_id=111-ORDER BY orderby",
	'... with the appropriate arguments' );

# destruct()
$mock->set_always( SUPER => 'super' );
$mock->{group} = $mock->{flatgroup} = 1;
destruct($mock);

is( $mock->call_pos( -1 ), 'SUPER', 'destruct() should call SUPER()' );
ok( ! exists $mock->{group}, '... should delete the "group" variable' );
ok( ! exists $mock->{flatgroup}, '... and the "flatgroup" variable' );

# insert()
$mock->set_series( hasAccess => ( 0, 1  ) )
	 ->set_true( 'updateGroup' )
	 ->clear();

ok( ! insert($mock, 'user'), 
	'insert() should return false if user cannot create node' );
($method, $args) = $mock->next_call();
is( $method, 'hasAccess', '... calling hasAccess to check' );
is( join('-', @$args), "$mock-user-c", '... user create permissions' );

$mock->{group} = 'foo';
ok( insert($mock, 'user2'), '... should return node_id if check succeeds' );
is( $mock->next_call(2), 'SUPER', '... calling SUPER()' );
($method, $args) = $mock->next_call();
is( $method, 'updateGroup', '... calling updateGroup()' );
is( $args->[1], 'user2', '... with user' );

ok( ! insert( $mock ), '... and should return false with no user provided' );

# update()
$mock->set_always( SUPER => 4 )
	 ->clear();

is( update($mock, 8), 4, 'update() should return results of SUPER() call' );
($method, $args) = $mock->next_call();
is( $mock->next_call(), 'SUPER', '... so it should call SUPER()' );
is( $method, 'updateGroup', '... calling updateGroup() to update the group' );
is( $args->[1], 8, '... with the provided user' );

#  updateFromImport()
$mock->set_always( SUPER => 6 )
	 ->clear();

is( updateFromImport($mock, { group => 7 }, 'user'), 6,
	'updateFromImport() should return result of SUPER() call' );
($method, $args) = $mock->next_call();
is( $mock->next_call(), 'SUPER', '... and should call SUPER()' );
is( $mock->{group}, 7, '... should set group to new group' );
is( $method, 'updateGroup', '... and should call updateGroup()' );
is( $args->[1], 'user', '... with the user' );

# updateGroup()
$mock->set_always( hasAccess => 0 )
	 ->clear(); 
ok( ! updateGroup($mock), 'updateGroup() should return false with no user' );
ok( ! updateGroup($mock, 'user'), '... or if user has no write access' );
($method, $args) = $mock->next_call();
is( $method, 'hasAccess', '... so it must check access' );
is( join('-', @$args), "$mock-user-w", '... write access for user' );

$mock->{group} = [ 1, 2, 4, 8 ];
$mock->set_series( do => ( 1, 2 ) )
	 ->set_always( isGroup => 'gtable' )
	 ->set_true( 'hasAccess' )
	 ->set_always( restrict_type => $mock->{group}  )
	 ->set_series( selectGroupArray => ( [2, 4, 6, 10] ) )
	 ->set_true( 'sqlSelect' )
	 ->set_true( 'sqlInsert' )
	 ->set_true( 'sqlUpdate' )
	 ->set_true( 'sqlDelete' )
	 ->set_true( 'groupUncache' )
	 ->clear();

$mock->{DB} = $mock->{dbh} = $mock;
$mock->{node_id} = 411;

ok( updateGroup($mock, 'user'), '... should succeed otherwise' );
($method, $args) = $mock->next_call( 2 );
is( $method, 'restrict_type', '... should restrict group members' );
is( join('-', @$args), "$mock-$mock->{group}", '... to group' );
is( $mock->next_call(), 'isGroup', '... should fetch group table' );
is( $mock->next_call(), 'selectGroupArray', '... fetching group node_ids' );

my %group;
@group{ @$mock{group} } = ();
ok( ! (exists $group{6} and exists $group{10} ),
	'... should delete nodes that do not exist in new group' );
TODO:
{
	local $TODO = "This warning has disappeared, perhaps it should return?";

	like( $errors, qr/Wrong number of group members deleted!/,
		'... and should warn if deleting the wrong number of nodes' );
}
($method, $args) = $mock->next_call();

is( $method, 'sqlSelect', '... selecting max rank if inserting' );
is( join('-', @$args), "$mock-MAX(rank)-gtable-gtable_id=411",
	'... from proper table' );

($method, $args) = $mock->next_call();
is( $method, 'sqlInsert', '... and should insert new nodes' );
is( $args->[1], 'gtable', '... into the right table' );
is( $args->[2]{gtable_id}, 411, '... associated with the right group' );
is( $args->[2]{node_id}, 8, '... and the right node_id' );

($method, $args) = $mock->next_call( 13 );
is( $method, 'sqlUpdate', '... updating each node in group' );
is( $args->[1], 'gtable', '... in the group table' );
is( $args->[2]{orderby}, 3, '...with new order' );
like( $args->[3], qr/gtable_id=411.+node_id=8.+rank/,
	'... with the correct arguments' );
is( join(' ', @{ $mock->{group} }), '1 2 4 8', 
	'... and should assign new group to the node' );

# nuke()
$mock->{node_id} = 7;
$mock->{dbh} = $mock;

$mock->set_always( SUPER => 12 )
	 ->set_always( isGroup => 'table' )
	 ->set_series( hasAccess => (1, 0) )
	 ->set_true( 'getRef' )
	 ->clear();

is( nuke($mock, 'user'), 12, 'nuke() should return result of SUPER() call' );
is( $mock->next_call(), 'isGroup', '... should fetch group table' );
is( $mock->next_call(), 'getRef', '... should nodify user parameter' );
($method, $args) = $mock->next_call();
is( $method, 'hasAccess', '... should check for access' );
is( join('-', @$args), "$mock-user-d", '... user delete access' );
($method, $args) = $mock->next_call();
is( $method, 'sqlDelete', '... and should delete the node' );
is( join('-', @$args), "$mock-table-table_id=7", '... with the proper id' );

is( $mock->next_call(), 'SUPER', '... calling SUPER' );
ok( ! nuke($mock, ''), '... returning false if user cannot nuke this node' );

# isGroup()
$mock->{type}{derived_grouptable} = 77;
is( isGroup($mock), 77, 'isGroup() should return derived group table' );

# inGroupFast()
$mock->{group} = [ 1, 3, 5, 7, 17, 43 ];
$mock->set_series( getId => 17, 44 )
	 ->set_true( 'groupCache' )
	 ->set_always( 'existsInGroupCache', 'cached?' )
	 ->clear();

$result = inGroupFast($mock, 'node!');
($method, $args) = $mock->next_call();
is( $method, 'getId', 'inGroupFast() should find node_id' );
is( $args->[1], 'node!', '... of node' );
is( $mock->next_call(), 'groupCache', '... populating cache' );
is( $result, 'cached?', '... returning result of cache lookup' );

# inGroup()
ok( ! inGroup($mock), 'inGroup() should return false if no node is provided' );

$mock->set_always( selectNodegroupFlat => 'flat' )
	 ->set_always( getId => 'node_id' )
	 ->set_series( hasGroupCache => ( 0, 1 ) )
	 ->set_always( existsInGroupCache => 'cached?' )
	 ->clear();

$result = inGroup($mock, 'foo');
($method, $args) = $mock->next_call();
is( $method, 'getId', '... should make sure it has a node_id' );
is( $args->[1], 'foo', '... with the node parameter' );

($method, $args) = $mock->next_call();
is( $method, 'hasGroupCache', "... checking if there's a group cache" );

($method, $args) = $mock->next_call();
is( $method, 'selectNodegroupFlat',
	'... should call selectNodegroupFlat() to get all group members (if not)' );

($method, $args) = $mock->next_call();
is( $method, 'groupCache', '... caching results' );
is( $args->[1], 'flat', '... with flat nodegroup' );

($method, $args) = $mock->next_call();
is( $method, 'existsInGroupCache', '... checking group cache' );
is( $args->[1], 'node_id', '... with node_id' );
is( $result, 'cached?', '... returning result' );

$mock->clear();
inGroup( $mock, 'bar' );
is( $mock->next_call( 3 ), 'existsInGroupCache',
	'... not rebuilding cache if it exists' );
ok( ! inGroup(), '.... returning false if no node is provided' );

# selectNodegroupFlat()
$mock->{flatgroup} = 17;
is( selectNodegroupFlat($mock), 17, 
	'selectNodegroupFlat() should return cached group, if it exists' );
delete $mock->{flatgroup};

my $traversed = { 
	$mock->{node_id} => 1,
};
is( selectNodegroupFlat($mock, $traversed), undef,
	'... or false if it has seen this node before' );

$traversed = {};
$mock->set_series( getNode => ( $mock, undef, $mock ))
	 ->set_series( isGroup => ( 1, 0 ))
	 ->set_always( selectNodegroupFlat => [ 4, 5 ] )
	 ->clear();

$mock->{group} = [ 1, 2 ];

$result = selectNodegroupFlat($mock, $traversed);
ok( exists $traversed->{ $mock->{node_id} }, 
	'... should mark this node as seen' );

($method, $args) = $mock->next_call();
is( $method, 'getNode', '... should fetch each node in group' );
is( $args->[1], 1, '... by node_id' );
is( $mock->next_call(), 'isGroup', 
	'... checking if node is a group node' );

($method, $args) = $mock->next_call();
is( $method, 'selectNodegroupFlat', '... fetching group nodes' );
is( $args->[1], $traversed, '... passing traversed hash' );
is( join(' ', @$result), '4 5', '... returning list of contained nodes' );
is( $mock->{flatgroup}, $result, '... and should cache group' );

# insertIntoGroup()
ok( ! insertIntoGroup($mock), 
	'insertIntoGroup() should return false unless a user is provided' );
ok( ! insertIntoGroup($mock, 1), '... or if no insertables are provided' );

$mock->set_series( hasAccess => ( 0, 1, 1 ) );
ok( ! insertIntoGroup($mock, 'user', 1), 
	'... or if user does not have write access' );

($method, $args) = $mock->next_call( 2 );
is( $method, 'hasAccess', '... so it should check access' );
is( join('-', @$args), "$mock-user-w", '... write access for user' );

$mock->set_series( restrict_type => ( [ 1 .. 3 ], [ 4 ] ))
	 ->set_series( getId => 3, 2, 1, 4 )
	 ->clear();

insertIntoGroup($mock, 'user', 1, 1);
($method, $args) = $mock->next_call( 2 );

is( $method, 'restrict_type', '... checking for type restriction on group' );
isa_ok($args->[1], 'ARRAY', '... allowing an insertion refs that is scalar or');

my $count;
while ($method = $mock->next_call())
{
	$count++ if $method eq 'getId';
}

is( $count, 3, '... should get node id of insertion' );
is( join(' ', @{ $mock->{group} }), '1 3 2 1 2',
	'... should update "group" field' );
ok( ! exists $mock->{flatgroup}, '... and delete "flatgroup" field' );
ok( insertIntoGroup( $mock, 'user', 1 ), '... should return true on success' );
is( join(' ', @{ $mock->{group} }), '1 3 2 1 2 4', 
	'... appending new nodes if no position is given' );

# removeFromGroup()
ok( ! removeFromGroup($mock), 
	'removeFromGroup() should return false unless a user is provided' );
ok( ! removeFromGroup($mock, 'user'), '... or if no insertables are provided' );

$mock->set_series( hasAccess => ( 0, 1 ))
	 ->clear();

ok( ! removeFromGroup($mock, 6, 'user'), 
	'... or if user does not have write access' );
($method, $args) = $mock->next_call();
is( $method, 'hasAccess', '... checking for access' );
is( join('-', @$args), "$mock-user-w", '... write access for user' );

$mock->set_always( hasAccess => ( 1 ))
	 ->set_always( getId => ( 6 ))
	 ->clear();

$mock->{_calls} = [];
$mock->{group} = [ 3, 6, 9, 12 ];

$result = removeFromGroup($mock, 6, 'user' );
($method, $args) = $mock->next_call( 2 );
is( $method, 'getId', '... should get node_id' );
is( $args->[1], 6, '... of removable node' );

is( join(' ', @{ $mock->{group} }), '3 9 12', 
	'... should assign new "group" field without removed node' );
ok( $result, '... should return true on success' );
ok( ! exists $mock->{flatgroup}, '... deleting the cached flat group' );
is( $mock->next_call(), 'groupUncache', '... and uncaching group' );

# replaceGroup()
$mock->set_series( isGroup => ( '', 'table' ))
	 ->set_series( hasAccess => 0, 1 )
	 ->set_always( restrict_type => 'abc' )
	 ->clear();

$result = replaceGroup($mock, 'replace', 'user');

is( $mock->next_call(), 'isGroup', 'replaceGroup() should fetch group table' );
ok( ! $result, '... should return false if user does not have write access' );
($method, $args) = $mock->next_call();
is( $method, 'hasAccess', '... checking for access' );
is( join('-', @$args), "$mock-user-w", '... write access for user' );

$mock->{group} = $mock->{flatgroup} = 123;
$result = replaceGroup($mock, 'replace', 'user');

($method, $args) = $mock->next_call( 3 );
is( $method, 'restrict_type', '... restricting types of new group' );
isa_ok( $args->[1], 'ARRAY', '... constraining argument to something that ' );
is( $mock->{group}, 'abc', 
	'... should replace existing "group" field with new group' );
ok( !exists $mock->{flatgroup}, '... and should delete any "flatgroup" field' );
is( $mock->next_call(), 'groupUncache', '... uncaching group' );
ok( $result, '... should return true on success' );

# getNodeKeys()
$mock->set_series( SUPER => { foo => 1 }, { foo => 2 } )
	 ->clear();

$result = getNodeKeys($mock, 1);
is( $mock->next_call(), 'SUPER',
	'getNodeKeys() should call SUPER() to get parent type keys' );
isa_ok( $result, 'HASH', '... should return a hash reference of keys' );
ok( exists $result->{group}, 
	'... including a group key if the forExport flag is set' );
ok( ! exists getNodeKeys($mock)->{group}, '... excluding it otherwise' );

# fieldToXML()
$mock->set_series( SUPER => ( 5, 6, 7 ))
	 ->set_true( 'appendChild' )
	 ->clear();

$result = fieldToXML($mock, '', '');
is( $mock->next_call(), 'SUPER',
	'fieldToXML() should just call SUPER() if not handling a group field' );

is( $result, 5, '... returning the results' );
{
	local (*XML::DOM::Element::new, *XML::DOM::Text::new,
		*Everything::Node::nodegroup::genBasicTag);

	my @xd;
	*XML::DOM::Text::new = sub {
		push @xd, [ @_ ];
		return @_;
	};
	*XML::DOM::Element::new = sub {
		push @xd, [ @_ ];
		return $mock;
	};

	my @gbt;
	*Everything::Node::nodegroup::genBasicTag = sub {
		push @gbt, [ @_ ];
	};

	$mock->{group} = [ 3, 4, 5 ];
	$mock->clear();
	$result = fieldToXML($mock, 'doc', 'group', "\r");

	is( join(' ', @{ $xd[0] }), 'XML::DOM::Element doc group', 
		'... otherwise, it should create a new DOM group element' );

	my $count;
	for (1 .. 6)
	{
		($method, $args) = $mock->next_call();
		$count++ if $method eq 'appendChild';
	}

	is( $count, 6, '... appending each child as a Text node' );
	is( join(' ', map { $_->[3] } @gbt), '3 4 5', 
		'... noted with their node_ids' );
	is( $method, 'appendChild', '... and appending the whole thing' );
	is( $result, $mock, '... and should return the new element' );
}

# xmlTag()
my $gcn;
$mock->set_always( SUPER => 8 )
	 ->set_series( getTagName => '', 'group', 'group' )
	 ->set_series( getNodeType => 1, 2, 3 )
	 ->set_true( 'insertIntoGroup' )
	 ->clear();

$result = xmlTag($mock, $mock);
is( $mock->next_call(), 'getTagName', 'xmlTag() should get the tag name' );
is($mock->next_call(), 'SUPER', '... calling SUPER() if it is not a group tag');
is( $result, 8, '... returning the results' );

$mock->clear();

{
	local *XML::DOM::TEXT_NODE;
	*XML::DOM::TEXT_NODE = sub { 3 };

	$mock->mock( getChildNodes => sub { return if $gcn++; return ($mock) x 3 });
	local *Everything::XML::parseBasicTag;

	my @parses = ({
		where => 'where',
	}, {
		name => 'me',
		me => 'node',
	});
	*Everything::XML::parseBasicTag = sub {
		return shift @parses;
	};
	$result = xmlTag($mock, $mock);

	is( $gcn, 1, '... but if it is, should get the child nodes' );
	isa_ok( $result, 'ARRAY', 
		'... and should return existing fixup nodes in something that' );

	my @inserts;
	while (($method, $args) = $mock->next_call())
	{
		push @inserts, $args if $method eq 'insertIntoGroup';
	}

	is( scalar @inserts, 2, '... and should skip text nodes' );
	is( $result->[0]{fixBy}, 'nodegroup', '... should parse nodegroup nodes' );
	is( join(' ', map { $_->[3] } @inserts), '0 1',
		'... inserting each into the nodegroup in order' );
	is( join('|', @{ $inserts[0] }), "$mock|-1|-1|0",
		'... as a dummy node if a where clause is provided' );
	is( join('|', @{ $inserts[1] }), "$mock|-1|node|1",
		'... or by name if a name is provided' );

	ok( ! xmlTag($mock, $mock), '... should return nothing with no fixups' );
}

# applyXMLFix()
$mock->set_always( SUPER => 14 )
	 ->clear();

my $fix = { fixBy => 'foo' };
$result = applyXMLFix( $mock, $fix );
is( $mock->next_call(), 'SUPER', 
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

	$mock->set_series( getNode => { node_id => 111 }, 0, 0 );

	$fix = {
		fixBy   => 'nodegroup',
		orderby => 1, 
	};

	$result = applyXMLFix( $mock, $fix );
	ok( $pxw, '... should call patchXMLwhere() to get the right node data' );
	($method, $args) = $mock->next_call();
	is( $method, 'getNode', '... attemping to get the node' );
	is( $args->[1]{type_nodetype}, 'type', '... with the where hashref' );
	is( $mock->{group}[1], 111,
		'... replacing dummy node with fixed node on success' );
	
	$mock->{title} = 'title';
	$mock->{type}  = { title => 'typetitle' };

	$result = applyXMLFix( $mock, $fix, 1);
	like( $errors, qr/Unable to find 'title' of type/,
		'... should warn about missing node if error flag is set' );

	$errors = '';
	$result = applyXMLFix( $mock, $fix );
	is( $errors, '', '... but should not warn without flag' );

	isa_ok( $result, 'HASH', '... should return fixup data if it failed' );
}

# clone()
$mock->set_series( SUPER => undef, ($mock) x 2 )
	 ->set_true( 'update' )
	 ->clear();

$result = clone($mock, 'user');
($method, $args) = $mock->next_call();
is( $method, 'SUPER', 'clone() should call SUPER()' );
is( $args->[1], 'user', '... with the user' );
ok( ! $result, '... and should return false unless that succeeded' );

$mock->{group} = 'group';
$result = clone($mock, 'user');
is( $result, $mock, '... or the new node if it succeeded' );
($method, $args) = $mock->next_call( 2 );
is( $method, 'insertIntoGroup', '... inserting the group into the new node' );
is( join('-', @$args), "$mock-user-group", '... with the user and the group' );
($method, $args) = $mock->next_call();
is( $method, 'update', '... updating the node' );
is( $args->[1], 'user', '... with the user' );

delete $mock->{group};
$mock->{_calls} = [];
isnt( $mock->{_calls}[1], 'insertIntoGroup',
	'... but should avoid insert without a group in the parent' );

# restrict_type()
{
	local *Everything::Node::nodegroup::getNode;

	my @nodes = (0, 1, 2, 1);
	my @calls;
	*Everything::Node::nodegroup::getNode = sub {
		push @calls, [ @_ ];
		my $mocknum = shift @nodes;
		return $mocknum ? 
			{ restrict_nodetype => $mocknum, type_nodetype => $mocknum }:
			{ type => { restrict_nodetype => 1 }, type_nodetype => 0 };
	};

	$mock->{type_nodetype} = 6;
	$result = restrict_type($mock, 'group');

	is( $calls[0][0], 6,
		'restrict_type() should get the appropriate nodetype' );
	is( $result, 'group', 
		'... and should return group unchanged if there is no restriction' );
	
	$result = restrict_type($mock, [ 1 .. 4 ]);
	is( scalar @calls, 6,
		'... should get each node in group reference' );
	
	isa_ok( $result, 'ARRAY', 
		'... returning an array reference of proper nodes' );
	
	is( scalar @$result, 3,
		'... and should save nodes that are of the proper type' );
	is( $result->[2], 4, '... or group nodes that can contain the proper type');
}

# getNodeKeepKeys()
$mock->set_series( SUPER => { keep => 1, me => 1 })
	 ->clear();

$result = getNodeKeepKeys($mock);
is( $mock->next_call(), 'SUPER', 'getNodeKeepKeys() should call SUPER()' );
isa_ok( $result, 'HASH', '... returning something that' );
is( scalar keys %$result, 3, '... containing keys from SUPER() and an extra' );
ok( $result->{group}, '... and one key should be "group"' );

# conflictsWith()
$mock->{modified} = '';
ok( ! conflictsWith($mock), 
	'conflictsWith() should return false with no number in "modified" field' );

$mock->{modified} = 7;
$mock->{group}    = [ 1, 4, 6, 8 ];

$mock->set_always( SUPER => 11 )
	 ->clear();

my $group = { group => [ 1, 4, 6 ] };
is( conflictsWith($mock, $group ), 1,
	'... should return true if groups are different sizes' );

push @{ $group->{group} }, 9;
is( conflictsWith($mock, $group ), 1,
	'... should return true if a node conflicts between the two nodes' );

$result = conflictsWith( $mock, $mock );
is( $mock->next_call(), 'SUPER', '... calling SUPER() if that succeeds' );
is( $result, 11, '... returning the result' );
