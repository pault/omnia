#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
	@INC{'Everything.pm', 'Everything/XML.pm', 'XML/DOM.pm'} = (1, 1, 1);
}

use vars qw( $AUTOLOAD );

use TieOut;
use FakeNode;
use Test::More tests => 136;

use_ok( 'Everything::Node::nodegroup' );

my $node = FakeNode->new();

# construct()
$node->{_subs}{selectGroupArray} = [ 'group' ];

construct($node);
is( $node->{_calls}[0][0], 'selectGroupArray',
	'construct() should fetch the contained nodes' );
is( $node->{group}, 'group', '... and should set "group" field to results' );

# selectGroupArray()
$node->{node_id} = 111;
$node->{DB} = $node;
$node->{_subs} = {
	isGroup => [ 'grouptable' ],
	sqlSelectMany => [ $node ],
	fetchrow => [ 1, 7, 9, undef ],
};
$node->{_calls} = [];

my $result = selectGroupArray($node);
is( $node->{_calls}[0][0], 'isGroup',
	'selectGroupArray() should call isGroup() to get group table' );
is( ref $result, 'ARRAY',
	'... and should return a array reference of contained nodes' );
is( scalar @$result, 3, '... ALL of the nodes' );
is( join(' ', @{ $node->{_calls}[1] }), 'createGroupTable grouptable',
	'... should verify that the table exists' );
is( join(' ', @{ $node->{_calls}[2] }), 
	'sqlSelectMany node_id grouptable grouptable_id=111 ORDER BY orderby',
	'... and should select nodes from the group table' );

# destruct()
$node->{group} = $node->{flatgroup} = 1;
destruct($node);

is( $node->{_calls}[-1][0], 'SUPER', 'destruct() should call SUPER()' );
ok( ! exists $node->{group}, '... should delete the "group" variable' );
ok( ! exists $node->{flatgroup}, '... and the "flatgroup" variable' );

# insert()
$node->{_calls} = [];
$node->{_subs} = {
	hasAccess => [ 0, 1 ],
	SUPER => [ 'super!' ],
};

ok( ! insert($node, 'user'), 
	'insert() should return false if user cannot create node' );
is( join(' ', @{ $node->{_calls}[-1] }), 'hasAccess user c', 
	'... calling hasUser() to check' );

$node->{group} = 'foo';
ok( insert($node, 'user2'), '... should return node_id if check succeeds' );
is( $node->{_calls}[-2][0], 'SUPER', '... calling SUPER()' );
is( join(' ', @{ $node->{_calls}[-1] }), 'updateGroup user2',
	'... calling updateGroup() with user' );

# update()
$node->{_subs}{SUPER} = [ 4 ];
is( update($node, 8), 4, 'update() should return results of SUPER() call' );
is( $node->{_calls}[-1][0], 'SUPER', '... so it should call SUPER()' );
is( join(' ', @{ $node->{_calls}[-2] }), 'updateGroup 8', 
	'... calling updateGroup() with user to update the group' );

#  updateFromImport()
$node->{_subs}{SUPER} = [ 6 ];
is( updateFromImport($node, { group => 7 }, 'user'), 6,
	'updateFromImport() should return result of SUPER() call' );
is( $node->{_calls}[-1][0], 'SUPER', '... and should call SUPER()' );
is( $node->{group}, 7, '... should set group to new group' );
is( join(' ', @{ $node->{_calls}[-2] }), 'updateGroup user',
	'... and should call updateGroup() with the user' );

# updateGroup()
$node->{_subs}{hasAccess} = [ 0 ]; 
ok( ! updateGroup($node), 'updateNode() should return false with no user' );
ok( ! updateGroup($node, 'user'), '... or if user has no write access' );
is( join(' ', @{ $node->{_calls}[-1] }), 'hasAccess user w',
	'... so it must check for write access' );

$node->{group} = [ 1, 2, 4, 8 ];
$node->{_subs} = {
	do => [ 1, 2 ],
	isGroup => [ 'gtable' ],
	hasAccess => [ 1 ],
	restrict_type => [ $node->{group} ],
	selectGroupArray => [ [2, 4, 6, 10] ],
};
$node->{DB} = $node->{dbh} = $node;
$node->{node_id} = 411;
$node->{_calls} = [];

my $out = tie *STDERR, 'TieOut';

ok( updateGroup($node, 'user'), '... should succeed otherwise' );
is( join(' ', @{ $node->{_calls}[1] }), "restrict_type $node->{group}",
	'... should restrict group members' );
is( $node->{_calls}[2][0], 'isGroup', '... should fetch group table' );
is( $node->{_calls}[3][0], 'selectGroupArray', 
	'... should fetch group node_ids' );

my %group;
@group{ @$node{group} } = ();
ok( ! (exists $group{6} and exists $group{10} ),
	'... should delete nodes that do not exist in new group' );
like( $out->read(), qr/Wrong number of group members deleted!/,
	'... and should warn if deleting the wrong number of nodes' );
is( join(' ', @{ $node->{_calls}[4] }), 
	'sqlSelect MAX(rank) gtable gtable_id=411',
	'... should fetch max rank if inserting' );

my $insert = $node->{_calls}[5];
is( $insert->[0], 'sqlInsert', '... and should insert new nodes' );
is( $insert->[2]{gtable_id}, 411, '... associated with the right group' );
is( $insert->[2]{node_id}, 8, '... and the right node_id' );

$insert = $node->{_calls}[-1];
like( join(' ', @$insert[0, 1, 3]), 
	qr/^sqlUpdate gtable gtable_id=411.+node_id=8.+rank/,
	'... should update each node in group' );
is( $insert->[2]{orderby}, 3, '...with new order' );
is( join(' ', @{ $node->{group} }), '1 2 4 8', 
	'... and should assign new group to the node' );

# nuke()
$node->{node_id} = 7;
$node->{dbh} = $node;

$node->{_calls} = [];
$node->{_subs} = {
	SUPER		=> [ 12 ],
	isGroup		=> [ 'table' ],
	hasAccess	=> [ 1, 0 ],
};

is( nuke($node, 'user'), 12, 'nuke() should return result of SUPER() call' );
is( $node->{_calls}[0][0], 'isGroup', '... should fetch group table' );
is( $node->{_calls}[1][0], 'getRef', '... should nodify user parameter' );
is( join(' ', @{ $node->{_calls}[2] }), 'hasAccess user d', 
	'... should check for delete access' );
is( join(' ',@{ $node->{_calls}[3] }), 'do delete from table where table_id=7',
	'... and should delete from the table' );
ok( ! nuke($node, ''), '... and return false if user cannot nuke this node' );

# isGroup()
$node->{type}{derived_grouptable} = 77;
is( isGroup($node), 77, 'isGroup() should return derived group table' );

# inGroupFast()
$node->{group} = [ 1, 3, 5, 7, 17, 43 ];
$node->{_subs}{getId} = [ 17, 44 ];

$result = inGroupFast($node, 'node!');
is( join(' ', @{ $node->{_calls}[-1] }), 'getId node!', 
	'inGroupFast() should find node_id of node' );
ok( $result, '... should return true if node is in the group' );

ok( ! inGroupFast($node, ''), '... and false otherwise' );

# inGroup()
ok( ! inGroup($node), 'inGroup() should return false if no node is provided' );

$node->{_calls} = [];
$node->{_subs} = {
	selectNodegroupFlat => [ [ ($node) x 4 ], [ ($node) x 4 ] ],
	getId => [ 11, 1, 5, 7, 11, 13, 2, 4, 6, 8 ],
};

$result = inGroup($node, 'foo');
is( $node->{_calls}[1][0], 'selectNodegroupFlat',
	'... should call selectNodegroupFlat() to get all group members' );
ok( $result, '... should return true if node is in nodegroup' );
ok( ! inGroup($node, 'bar'), '... and false otherwise' );

# selectNodegroupFlat()
$node->{flatgroup} = 17;
is( selectNodegroupFlat($node), 17, 
	'selectNodegroupFlat() should return cached group, if it exists' );
delete $node->{flatgroup};

my $traversed = { 
	$node->{node_id} => 1,
};
is( selectNodegroupFlat($node, $traversed), undef,
	'... or false if it has seen this node before' );

$traversed = {};
$node->{_subs} = {
	getNode => [ $node, $node ],
	isGroup => [ 0, 1 ],
	selectNodegroupFlat => [ [4, 5] ],
};
$node->{_calls} = [];
$node->{group} = [ 1, 2 ];

$result = selectNodegroupFlat($node, $traversed);
ok( exists $traversed->{ $node->{node_id} }, 
	'... should mark this node as seen' );

is( join(' ', @{ $node->{_calls}[2] }), 'getNode 2', 
	'... should fetch each node in group' );
is( $node->{_calls}[3][0], 'isGroup', 
	'... should check if node is a group node' );
is( join(' ', @{ $node->{_calls}[4] }), "selectNodegroupFlat $traversed", 
	'... should recurse if it is' );
is( join(' ', @$result), "$node 4 5", 
	'... should return list of contained nodes' );
is( $node->{flatgroup}, $result, '... and should cache group' );

# insertIntoGroup()
ok( ! insertIntoGroup($node), 
	'insertIntoGroup() should return false unless a user is provided' );
ok( ! insertIntoGroup($node, 1), '... or if no insertables are provided' );
$node->{_subs}{hasAccess} = [ 0, 1, 1 ];
ok( ! insertIntoGroup($node, 'user', 1), 
	'... or if user does not have write access' );
is( join(' ', @{ $node->{_calls}[-1] }), 'hasAccess user w',
	'... so it should check for write access' );

$node->{_calls} = [];
$node->{_subs}{restrict_type} = [ [ 1 .. 3 ], [ 4 ] ];
$node->{_subs}{getId} = [ 3, 2, 1, 4 ];

insertIntoGroup($node, 'user', 1, 1);
is( $node->{_calls}[1][0], 'restrict_type',
	'... should check for type restriction on group' );
like( $node->{_calls}[1][1], qr/^ARRAY/, 
	'... and should allow scalar and array ref for insertion' );

is( scalar ( grep { $_->[0] eq 'getId' } @{ $node->{_calls} } ), 3, 
	'... should get node id of insertion' );
is( join(' ', @{ $node->{group} }), '1 3 2 1 2',
	'... should update "group" field' );
ok( ! exists $node->{flatgroup}, '... and delete "flatgroup" field' );
ok( insertIntoGroup( $node, 'user', 1 ), '... should return true on success' );
is( join(' ', @{ $node->{group} }), '1 3 2 1 2 4', 
	'... appending new nodes if no position is given' );

# removeFromGroup()
ok( ! removeFromGroup($node), 
	'removeFromGroup() should return false unless a user is provided' );
ok( ! removeFromGroup($node, 'user'), '... or if no insertables are provided' );
$node->{_subs}{hasAccess} = [ 0, 1 ];
ok( ! removeFromGroup($node, 6, 'user'), 
	'... or if user does not have write access' );
is( join(' ', @{ $node->{_calls}[-1] }), 'hasAccess user w',
	'... so it should check for write access' );

$node->{_subs} = {
	hasAccess => [ 1 ],
	getId => [ 6 ],
};
$node->{_calls} = [];
$node->{group} = [ 3, 6, 9, 12 ];

$result = removeFromGroup($node, 6, 'user' );
is( join(' ', @{ $node->{_calls}[1] }), 'getId 6',
	'... should get node_id of removable node' ),
is( join(' ', @{ $node->{group} }), '3 9 12', 
	'... should assign new "group" field without removed node' );
ok( $result, '... should return true on success' );

# replaceGroup()
$node->{_subs} = {
	isGroup			=> [ '', 'table' ],
	hasAccess		=> [ 0, 1 ],
	restrict_type	=> [ 'abc' ],
};
$node->{_calls} = [];
$result = replaceGroup($node, 'replace', 'user');

is( $node->{_calls}[0][0], 'isGroup', 
	'replaceGroup() should fetch group table' );
ok( ! $result, '... should return false if user does not have write access' );
is( join(' ', @{ $node->{_calls}[1] }), 'hasAccess user w',
	'... should check for restrictions' );

$node->{group} = $node->{flatgroup} = 123;
$result = replaceGroup($node, 'replace', 'user');

like( join(' ', @{ $node->{_calls}[4] }), qr/restrict_type ARRAY/,
	'... and should accept a scalar or array ref of new nodes' );
is( $node->{group}, 'abc', 
	'... should replace existing "group" field with new group' );
ok( !exists $node->{flatgroup}, '... and should delete any "flatgroup" field' );
ok( $result, '... should return true on success' );

# getNodeKeys()
$node->{_subs}{SUPER} = [ { foo => 1 }, { foo => 2 } ];

$result = getNodeKeys($node, 1);
is( $node->{_calls}[-1][0], 'SUPER',
	'getNodeKeys() should call SUPER() to get parent type keys' );
isa_ok( $result, 'HASH', '... should return a hash reference of keys' );
ok( exists $result->{group}, 
	'... including a group key if the forExport flag is set' );
ok( ! exists getNodeKeys($node)->{group}, '... excluding it otherwise' );

# fieldToXML()
$node->{_calls} = [];
$node->{_subs} = {
	SUPER => [ 5, 6, 7],
};

$result = fieldToXML($node, '', '');
is( $node->{_calls}[0][0], 'SUPER',
	'fieldToXML() should just call SUPER() if not handling a group field' );
is( $result, 5, '... returning the results' );
{
	local (*XML::DOM::Element::new, *XML::DOM::Text::new,
		*Everything::Node::nodegroup::genBasicTag);

	my @xd;
	*XML::DOM::Text::new		= sub {
		push @xd, [ @_ ];
		return @_;
	};
	*XML::DOM::Element::new		= sub {
		push @xd, [ @_ ];
		return $node;
	};

	my @gbt;
	*Everything::Node::nodegroup::genBasicTag = sub {
		push @gbt, [ @_ ];
	};

	$node->{group} = [ 3, 4, 5 ];
	$result = fieldToXML($node, 'doc', 'group', "\r");

	is( join(' ', @{ $xd[0] }), 'XML::DOM::Element doc group', 
		'... otherwise, it should create a new DOM group element' );

	is( scalar (grep { join(' ', @$_) =~ /^appendChild.+\n\r  /m } 
		@{ $node->{_calls} }), 3, '... appending each child as a Text node' );
	is( join(' ', map { $_->[3] } @gbt), '3 4 5', 
		'... noted with their node_ids' );
	is( $node->{_calls}[-1][0], 'appendChild',
		'... and appending the whole thing' );
	is( $result, $node, '... and should return the new element' );
}

# xmlTag()
$node->{_subs} = {
	SUPER => [ 8 ],
	getTagName => [ '', 'group', 'group' ],
	getNodeType => [ 1, 2, 3 ]
};

$result = xmlTag($node, $node);
is( $node->{_calls}[-2][0], 'getTagName', 'xmlTag() should get the tag name' );
is( $node->{_calls}[-1][0], 'SUPER', 
	'... and call SUPER() if it is not a group tag' );
is( $result, 8, '... returning the results' );
$node->{_calls} = [];
{
	local *XML::DOM::TEXT_NODE;
	*XML::DOM::TEXT_NODE = sub { 3 };

	local *FakeNode::getChildNodes;
	my $gcn;
	*FakeNode::getChildNodes = sub {
		return () if $gcn++;
		return ($node) x 3;
	};

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
	$result = xmlTag($node, $node);

	is( $gcn, 1, '... but if it is, should get the child nodes' );
	isa_ok( $result, 'ARRAY', 
		'... and should return array ref of fixup nodes if any exist' );

	my @inserts = grep /^insertIntoGroup/, 
		map { join(' ', @$_) } @{ $node->{_calls} };
	is( scalar @inserts, 2, '... and should skip text nodes' );
	is( $result->[0]{fixBy}, 'nodegroup', '... should parse nodegroup nodes' );
	is( join(' ', map { substr($_, -1, 1) } @inserts), '0 1',
		'... inserting each into the nodegroup in order' );
	is( $inserts[0], 'insertIntoGroup -1 -1 0',
		'... as a dummy node if a where clause is provided' );
	is( $inserts[1], 'insertIntoGroup -1 node 1',
		'... or by name if a name is provided' );

	ok( ! xmlTag($node, $node), '... should return nothing with no fixups' );

}

# applyXMLFix()
$node->{_subs} = {
	SUPER => [ 14 ],
};
$node->{_calls} = [];

my $fix = { fixBy => 'foo' };
$result = applyXMLFix( $node, $fix );
is( $node->{_calls}[0][0], 'SUPER',
	'applyXMLFix() should call SUPER() unless handling a nodegroup node' );
is( $result, 14, '... returning its results' );

{
	local *Everything::XML::patchXMLwhere;

	my $pxw;
	*Everything::XML::patchXMLwhere = sub {
		$pxw++;
		return { 
			title => 'title',
			field => 'field',
			type_nodetype => 'type',
		};
	};

	$node->{_subs} = {
		getNode => [ { node_id => 111 }, 0, 0 ],
	};
	$fix = {
		fixBy => 'nodegroup',
		orderby => 1, 
	};

	$$out = '';

	$result = applyXMLFix( $node, $fix );
	ok( $pxw, '... should call patchXMLwhere() to get the right node data' );
	like( join(' ', @{ $node->{_calls}[-1] }), qr/getNode HASH.+type/,
		'... and should try to get the node' );
	is( $node->{group}[1], 111,
		'... should replace dummy node with fixed node if it worked' );
	
	$result = applyXMLFix( $node, $fix, 1);
	like( $out->read(), qr/Unable to find 'title' of type/,
		'... should warn about missing node if error flag is set' );

	$result = applyXMLFix( $node, $fix );
	is( $out->read(), '', '... but should not warn without flag' );

	isa_ok( $result, 'HASH', '... should return fixup data if it failed' );
}

# clone()
$node->{_calls} = [];
$node->{_subs} = {
	SUPER => [ undef, $node, $node ],
};

$result = clone($node, 'user');
is( join(' ', @{ $node->{_calls}[0] }), 'SUPER user', 
	'clone() should call SUPER()' );
ok( ! $result, '... and should return false unless that succeeded' );

$node->{group} = 'group';
$result = clone($node, 'user');
is( $result, $node, '... or the new node if it succeeded' );
is( join(' ', @{ $node->{_calls}[2] }), 'insertIntoGroup user group',
	'... should insert the group into the new node, if both exist' );
is( join(' ', @{ $node->{_calls}[3] }), 'update user',
	'... and should update the new node' );

delete $node->{group};
$node->{_calls} = [];
isnt( $node->{_calls}[1], 'insertIntoGroup',
	'... but should avoid insert without a group in the parent' );

# restrict_type()
{
	local *Everything::Node::nodegroup::getNode;

	my @nodes = (0, 1, 2, 1);
	my @calls;
	*Everything::Node::nodegroup::getNode = sub {
		push @calls, [ @_ ];
		my $nodenum = shift @nodes;
		return $nodenum ? 
			{ restrict_nodetype => $nodenum, type_nodetype => $nodenum }:
			{ type => { restrict_nodetype => 1 }, type_nodetype => 0 };
	};

	$node->{type_nodetype} = 6;
	$result = restrict_type($node, 'group');

	is( $calls[0][0], 6,
		'restrict_type() should get the appropriate nodetype' );
	is( $result, 'group', 
		'... and should return group unchanged if there is no restriction' );
	
	$result = restrict_type($node, [ 1 .. 4 ]);
	is( scalar @calls, 6,
		'... should get each node in group reference' );
	
	isa_ok( $result, 'ARRAY', 
		'... returning an array reference of proper nodes' );
	
	is( scalar @$result, 3,
		'... and should save nodes that are of the proper type' );
	is( $result->[2], 4, '... or group nodes that can contain the proper type');
}

# getNodeKeepKeys()
$node->{_subs} = {
	SUPER => [{ keep => 1, me => 1 }],
};

$result = getNodeKeepKeys($node);
is( $node->{_calls}[-1][0], 'SUPER', 'getNodeKeepKeys() should call SUPER()' );
is( ref $result, 'HASH', '... returning a hash' );
is( scalar keys %$result, 3, '... containing keys from SUPER() and an extra' );
ok( $result->{group}, '... and one key should be "group"' );

# conflictsWith()
$node->{modified} = '';
ok( ! conflictsWith($node), 
	'conflictsWith() should return false with no number in "modified" field' );

$node->{modified} = 7;
$node->{group} = [ 1, 4, 6, 8 ];
$node->{_subs}{SUPER} = [ 11 ];

is( conflictsWith($node, { group => [ 1, 4, 6, 9 ] }), 1,
	'... should return true if a node conflicts between the two nodes' );

$result = conflictsWith( $node, $node );
is( $node->{_calls}[-1][0], 'SUPER', 
	'... and should call SUPER() if that succeeds' );
is( $result, 11, '... returning results of the SUPER() call' );

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
