#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib', '..';
}

use TieOut;
use FakeNode;
use Test::More tests => 188;

my $node = FakeNode->new();

# fake this up -- imported from Everything::NodeBase
local *Everything::Node::node::DB;
*Everything::Node::node::DB = \$node;

my $result;
{
	$INC{'DBI.pm'} = $INC{'Everything.pm'} =
		$INC{'Everything/NodeBase.pm'} = $INC{'Everything/XML.pm'} = 1;

	local (*DBI::import, *Everything::import, *Everything::NodeBase::import,
		*Everything::XML::import);

	my %import;
	*DBI::import = *Everything::import = *Everything::NodeBase::import = 
		*Everything::XML::import = sub {
			$import{+shift}++;
	};

	use_ok( 'Everything::Node::node' );
	is( scalar keys %import, 4, 
		'Everything::Node::node should use several packages' );
}


# construct()
ok( construct(), 'construct() should return true' );

# destruct()
ok( destruct(), 'destruct() should return true' );

# insert()
$node->{node_id} = 5;
$node->{_subs} = {
	getId => [ 4 .. 7 ],
	hasAccess => [ 0, 1, 1, 1 ],
	sqlSelect => [ 1, 0, 1, 1 ],
};
is( insert($node, $node), 0, 
	'insert() should return 0 if user lacks create access' );
is( join(' ', @{ $node->{_calls}[-1] }), "hasAccess $node c",
	'... so should check for create access' );
is( $node->{_calls}[-2][0], 'getId', 
	'... and should get node_id of inserting user' );
is( insert($node, $node), 5, 
	'... and should return it if it has already been inserted' );

$node->{_calls} = [];
$node->{node_id} = 0;
$node->{type} = $node;
$node->{restrictdupes} = 1;
$node->{DB} = $node;
is( insert($node, ''), 0, 
	'... and should return 0 if dupes are restricted and exist' );
is( $node->{_calls}[-3][0], 'getId', '... so it must fetch type node_id' );
like( join(' ', @{ $node->{_calls}[-1] }), 
	qr/sqlSelect.+node title=.+_nodetype=/, 
	'... and should select matching nodes' );


$node->{getNode} = [ { key => 'value' } ];
$node->{foo} = 11;

delete $node->{type}{restrictdupes};
{
	package FakeNode;
	local (*hasAccess, *getTableArray, *getFields, *getNode, *sqlSelect,
		*sqlInsert);

	my (@ha, @gta, @gf, @gn, @ss, @si);

	*hasAccess = sub {
		push @ha, [ @_ ];
		return 1;
	};

	*getTableArray = sub {
		push @gta, [ @_ ];
		return [ 'table' ];
	};

	*getFields = sub {
		push @gf, [ @_ ];
		return 'foo';
	};

	*getNode = sub {
		push @gn, [ @_ ];
		return {};
	};

	*sqlSelect = sub {
		push @ss, [ @_ ];
		return 87;
	};

	# i feel dirty, but this worked around a misfeature
	*sqlInsert = sub {
		my @args = @_;
		$args[2] = { %{ $args[2] } };
		push @si, \@args;
	};

	package main;

	$node->{node_id} = 0;
	ok( $result = insert($node, 'user'), 
		'... but should return node_id if no dupes exist' );

	is( $si[0][2]{-createtime}, 'now()',
		'... should set "-createtime" field to now()' );
	is( $si[0][2]->{author_user}, 'user',
		'... should ensure "author_user" field is set' );
	ok( exists $si[0][2]{hits}, '... should initialize "hits" field' );
	like( join(' ', @{ $si[0] }), qr/^\Q$node\E node HASH/,
		'... should insert node' );
	ok( exists $si[0][2]{foo}, '... including important fields' );
	is( $ss[0][1], 'LAST_INSERT_ID()', '... and must get node id' );

	is( $gta[0][0], $node, '... should fetch node tables' );

	is( $gf[1][1], 'table', '... and should fetch table fields' );
	is( $si[1][1], 'table', '... inserting data in each table' );
	is( $si[1][2]{table_id}, 87, '... including the identifier' );
	is( join(' ', @{ $gn[0] }), "$node 87 force",
		'... should perform a forceable fetch' );
	is( $node->{_calls}[-1][0], 'cache', 
		'... and should cache node' );
}

# update()
$node->{node_id} = 87;
$node->{_subs} = {
	hasAccess => [ 0, 1, 1 ],
	updateWorkspaced => [ 77, 0 ],
};
is( update($node, 'user'), 0, 
	'update() should return 0 if user lacks write access' );
is( join(' ', @{ $node->{_calls}[-1] }), 'hasAccess user w',
	'... so it should check for it' );

$node->{workspace}{nodes}{ $node->{node_id} } = 1;
$node->{DB} = $node;
$node->{cache} = $node;
$result = update($node, 'user');
is( join(' ', @{ $node->{_calls}[-1] }), 'updateWorkspaced user',
	'... should update workspaced node if it is workspaced' );
is( $result, 77, '... and should return the id if it that works' );

delete $node->{workspace};
$node->{type} = $node;
$node->{_calls} = [];
$node->{_subs}{getTableArray} = [ [ 'table', 'table2' ] ];
$node->{_subs}{getFields} = [ 'boom', 'foom' ];
$node->{boom} = 88;
$node->{foom} = 99;

update($node, 'user');
is( join(' ', @{ $node->{_calls}[1] }), "incrementGlobalVersion $node",
	'... should increment node version in cache' );
is( $node->{_calls}[2][0], 'cache', '... and should cache node' );
is( join(' ', @{ $node->{_calls}[3] }), 'sqlSelect now()',
	'... and should update "modified" field without flag' );
is( $node->{_calls}[4][0], 'getTableArray', '... should fetch type tables' );
is( join(' ', @{ $node->{_calls}[5] }), 'getFields table',
	'... and should fetch the fields of each table' );

my $call = $node->{_calls}[6];
is( join(' ', @$call[0, 1]), 'sqlUpdate table', 
	'... should update each table' );
is( scalar keys %{ $call->[2] }, 1, '... with only allowed fields' );
is( $call->[3], "table_id=$node->{node_id}", '... and table uid' );

# nuke()
$node->{_subs} = {
	hasAccess => [ 0, 1 ],
	isGroupType => [ 0, 'table1', 'table2' ],
	sqlSelectMany => [ 0, $node ],
	getTableArray => [ [ 'deltable'] ],
	fetchrow => [ 'group' ],
	do => [ 1, 1, 1 ],
};

$result = nuke($node, 'user');
is( join(' ', @{ $node->{_calls}[-2] }), 'getRef user',
	'nuke() should fetch user node unless it is -1' );
ok( ! $result, '... and should return false if user lacks delete access' );
is( join(' ', @{ $node->{_calls}[-1] }), 'hasAccess user d',
	'... so it should check for delete access' );

$node->{dbh} = $node;
$node->{_calls} = [];
{
	local *FakeNode::getAllTypes;

	my $gat;
	*FakeNode::getAllTypes = sub { $gat++; return ($node) x 3 };

	$result = nuke($node, -1);
	ok( $gat, '... should get all nodetypes' );
}

isnt( $node->{_calls}[0][0], 'getRef', 
	'... and should not get user node if it is -1' );
like( $node->{_calls}[3][1], qr/DELETE FROM links WHERE to_node.+from_node/,
	'... should delete from or to links in links table' );
is( $node->{_calls}[4][0], 'isGroupType', 
	'... should check each type is a group node' );

is( join(' ', @{ $node->{_calls}[6] }), 
	'sqlSelectMany table1_id table1 node_id=87',
	'... should check for node in group table' );
is( $node->{_calls}[9][0], 'fetchrow',
	'... if it exists, should fetch all containing groups' );
like( join(' ', @{ $node->{_calls}[12] }), qr/do DELETE FROM table2.+e_id=87/,
	'... and should delete from table' );
is( join(' ', @{ $node->{_calls}[13] }), 'getNode group', 
	'... and fetch containing node' );
is( $node->{_calls}[14][0], 'incrementGlobalVersion', '... forcing a reload' );
is( join(' ', @{ $node->{_calls}[15] }), 'getTableArray 1',
	'... should fetch all tables for node' );
like( join(' ', @{ $node->{_calls}[17] }),
	qr/do DELETE FROM deltable WHERE deltable_id=/,
	'... should delete node from tables' );
is( join(' ', @{ $node->{_calls}[18] }), "incrementGlobalVersion $node",
	'... should mark node as updated in cache' );
is( join(' ', @{ $node->{_calls}[19] }), "removeNode $node",
	'... and remove it from cache' );
is( $node->{node_id}, 0, '... should reset node_id' );
ok( $result, '... and return true' );

# getNodeKeys()
$node->{_calls} = [];

my %keys = map { $_ => 1 } 
	qw( createtime modified hits reputation
	lockedby_user locktime lastupdate foo_id bar );

$node->{_subs} = {
	getNodeDatabaseHash => [ \%keys, \%keys ],
};

$result = getNodeKeys($node);

is( $node->{_calls}[0][0], 'getNodeDatabaseHash',
	'getNodeKeys() should fetch node database keys' );
is( scalar keys %$result, 9, 
	'... and should return them unchanged, if not exporting' );

$result = getNodeKeys($node, 1);
ok( ! exists $result->{foo_id}, '... should return no uid keys if exporting' );
is( join(' ', keys %$result), 'bar', 
	'... and should remove non-export keys as well' );

# isGroup()
ok( ! isGroup(), 'isGroup() should return false' );

# getFieldDatatype()
$node->{a_field} = 111;
is( getFieldDatatype($node, 'a_field'), 'noderef',
	'getFieldDatatype() should mark node references as "noderef"' );

$node->{b_field} = 'foo';
$node->{cfield} = 112;
is( getFieldDatatype($node, 'b_field'), 'literal_value',
	'... but references without ids are literal' );
is( getFieldDatatype($node, 'bfield'), 'literal_value',
	'... and so are fields without underscores' );

# hasVars()
ok( ! hasVars(), 'hasVars() should return false' );

# clone()
{
	local *Everything::Node::node::getNode;

	my @gn;
	my $gnode = { node_id => 1 };
	*Everything::Node::node::getNode = sub {
		push @gn, [ @_ ];
		return $gnode;
	};
	$node->{restrictdupes} = 1;

	clone($node, '', 'title' );
	is( join(' ', @{ $gn[0] }), "title $node create",
		'clone() should create a new node of the right type' );

	$node->{restrictdupes} = 0;
	$result = clone($node, '', 'title');
	is( join(' ', @{ $gn[1] }), "title $node create force",
		'... should force creation if nodetype restricts duplicates' );
	ok( ! $result,
		'... and should return false if node exists and dupes are prohibited' );

	$gnode->{node_id} = 0;

	# yuck
	bless($gnode, 'FakeNode');

	$gnode->{_subs} = {
		insert => [ 0, 1 ],
	};

	$result = clone({}, 'user');

	is( join(' ', @{ $gnode->{_calls}[0] }), 'insert user',
		'... should insert new node on behalf of user' );

	ok( ! $result, '... should return false if it fails' );
	$result = clone({ title => 1, node_id => 4, foo_id => 5, createtime => 6, 
		foo => 1, bar => 2}, 'user');

	is( $result, $gnode,
		'... or clone if insert succeeds' );
	
	ok( ! exists $result->{title}, '... and should not clone title' );
	ok( ! exists $result->{createtime}, '... or createtime' );

	# node_id should already exist
	is( scalar grep(/_id$/, keys %$gnode), 1, '... or id fields' );
	is( join('', @$gnode{'foo', 'bar'}), '12', '... while keeping the others' );
}

# fieldToXML()
{
	local *Everything::Node::node::genBasicTag;

	my @gbt;
	*Everything::Node::node::genBasicTag = sub {
		push @gbt, [ @_ ];
		return 'tag';
	};

	$node->{afield} = 'thisfield';
	is( fieldToXML($node, $node, 'afield'), 'tag',
		'fieldToXML() should return an XML tag element' );
	is( scalar @gbt, 1, '... and should call genBasicTag()' );
	is( join(' ', @{ $gbt[0] }), "$node field afield thisfield", 
		'... with the correct arguments' );
}

# xmlTag()
$node->{_calls} = [];
$node->{_subs} = {
	getTagName => [ 'badtag', 'field', 'morefield' ],
};

$node->{title} = 'thistype';
my $out;
{
	local *STDOUT;
	$out = tie *STDOUT, 'TieOut';
	$result = xmlTag($node, $node);
	is( $node->{_calls}[0][0], 'getTagName', 'xmlTag() should fetch tag name' );
	ok( ! $result, '... and should return false unless it contains "field"' );
	like( $out->read(), qr/Error.+tag 'badtag'.+thistype/, 
		'... logging an error' );

	local *Everything::XML::parseBasicTag;
	my @pbt;
	my $parse = { name => 'parsed', parsed => 11 };
	*Everything::XML::parseBasicTag = sub {
		push @pbt, [ @_ ];
		return $parse;
	};
	
	$result = xmlTag($node, $node);
	is( join(' ', @{ $pbt[0] }), "$node node", '... should parse tag' );
	is( $result, undef, '... should return false with no fixes' );
	is( $node->{parsed}, 11, '... and should set node field to tag value' ); 

	$parse->{where} = 1;
	$result = xmlTag($node, $node);
	isa_ok( $result, 'ARRAY', '... should return array ref if fixes exist' );
	is( $result->[0], $parse, '... with the fix in the array ref' );
	is( $node->{parsed}, -1, '... setting node field to -1' );
}

# xmlFinal()
$node->{_calls} = [];
$node->{_subs} = {
	existingNodeMatches => [ $node, 0 ],
};
$result = xmlFinal($node);

is( $node->{_calls}[0][0], 'existingNodeMatches',
	'xmlFinal() should check for a matching node' );
is( join(' ', @{ $node->{_calls}[1] }), "updateFromImport $node -1",
	'... and should update node if so' );
is( $result, $node->{node_id}, '... returning the node_id' );

$result = xmlFinal($node);
is( join(' ', @{ $node->{_calls}[-1] }), 'insert -1',
	'... or should insert the node' );
is( $result, $node->{node_id}, '... returning the new node_id' );

# applyXMLFix()
{
	local *STDOUT;
	$out = tie *STDOUT, 'TieOut';

	my $where = { title => 'title', type_nodetype => 'type', field => 'b' };
	my $fix = { where => $where, field => 'fixme' };

	is( applyXMLFix($node, $fix), $fix,
		'applyXMLFix() should return fix if it has no "fixBy" field' );

	$fix->{fixBy} = 'fixme';
	is( applyXMLFix($node, $fix, 1), $fix,
		'... or if the field is not set to "node"' );
	like( $out->read(), qr/Error!.+handle fix by 'fixme'/, 
		'... and should log error if flag is set' );
	
	$fix->{fixBy} = 'node';

	local *Everything::XML::patchXMLwhere;
	my @pxw;
	*Everything::XML::patchXMLwhere = sub {
		push @pxw, [ @_ ];
		return $_[0];
	};

	$node->{_subs} = {
		getNode => [ 0, 0, { node_id => 42 } ],
	};

	$result = applyXMLFix($node, $fix);
	is( $pxw[0][0], $where, '... should try to resolve node' );
	is( join(' ', @{ $node->{_calls}[-1] }), "getNode $where type",
		'... should fetch resolved node' );
	is( $result, $fix, '... returning the fix if that did not work' );
	is( $out->read(), '', '... returning no error without flag' );
	$result = applyXMLFix($node, $fix, 1);
	like( $out->read(), qr/Error.+find 'title' of type 'type'.+field b/,
		'... and logging an error if flag is set' );

	$result = applyXMLFix($node, $fix);
	is( $node->{fixme}, 42, '... should set field to found node_id' );
	ok( ! $result, '... should return nothing on success' );
}

# commitXMLFixes()
commitXMLFixes($node);
is( join(' ', @{ $node->{_calls}[-1] }), 'update -1 nomodify',
	'commitXMLFixes() should call update() on node' );

# getIdentifyingFields()
is( getIdentifyingFields($node), undef, 
	'getIdentifyingFields() should return undef' );

# updateFromImport()
delete @$node{keys %$node};

$node->{_calls} = [];
$node->{_subs} = {
	getNodeKeys => [{ foo => 1, bar => 2, baz => 3 }],
	getNodeKeepKeys => [{ bar => 1 }],
};

updateFromImport($node, { foo => 1, bar => 2, baz => 3 }, 'user');
is( join(' ', @{ $node->{_calls}[0] }), 'getNodeKeys 1',
	'updateFromImport() should fetch node keys' );
is( $node->{_calls}[1][0], 'getNodeKeepKeys', '... and keys to keep' );
is( $node->{foo} + $node->{baz}, 4, '... should merge node keys' );
ok( ! exists $node->{bar}, '... but not those that should be kept' );
is( join(' ', @{ $node->{_calls}[2] }), 'update user nomodify',
	'... and should update node' );
is( $node->{modified}, 0, '... and should set "modified" to 0' );

# conflictsWith()
$node->{modified} = '';
ok( ! conflictsWith($node), 
	'conflictsWith() should return false with no digit in "modified" field' );

$node->{_calls} = [];
$node->{modified} = 1;

my $conflict = { foo => 1, bar => 2 };
my $keep = { foo => 1 };
$node->{_subs} = {
	getNodeKeys => [ $node, $node ],
	getNodeKeepKeys => [ $keep, {} ],
};

$node->{foo} = 1;
$node->{bar} = 3;
$result = conflictsWith($node, $conflict);
is( join(' ', @{ $node->{_calls}[0] }), 'getNodeKeys 1',
	'... and should fetch node keys' );
is( $node->{_calls}[1][0], 'getNodeKeepKeys', '... and keepable keys' );

ok( $result, '... should return true if any node field conflicts' );

$node->{bar} = 2;
ok( ! conflictsWith($node, $conflict), '... false otherwise' );

$node->{foo} = 2;
ok( ! conflictsWith($node, $conflict), '... and should ignore keepable keys' );

# getNodeKeepKeys()
$result = getNodeKeepKeys($node);
isa_ok( $result, 'HASH', 'getNodeKeepKeys() should return a hash reference' );
foreach my $class (qw( author group other guest )) {
	ok( $result->{"${class}access"}, "... and should contain $class access" );
	ok( $result->{"dynamic${class}_permission"}, 
		"... and $class permission keys" );
}
ok( $result->{loc_location}, '... and location key' );

# verifyFieldUpdate()
my @fields;
foreach my $field ( 'createtime', 'node_id', 'type_nodetype', 'hits',
	'loc_location', 'reputation', 'lockedby_user', 'locktime', 'authoraccess',
	'groupaccess', 'otheraccess', 'guestaccess', 'dynamicauthor_permission',
	'dynamicgroup_permission', 'dynamicother_permission', 
	'dynamicguest_permission') {
	push @fields, $field unless verifyFieldUpdate($node, $field);
}

is( scalar @fields, 16, 
	'verifyFieldUpdate() should return false for unmodifiable fields' );
ok( ! verifyFieldUpdate($node, 'foo_id'), 
	'... and for primary key (uid) fields' );
ok( verifyFieldUpdate($node, 'agoodkey'), '... but true for everything else' );

# getRevision()
$node->{node_id} = 11;
$node->{DB} = $node;
$node->{workspace}{node_id} = 7;
$node->{_calls} = [];
$node->{_subs} = {
	sqlSelectHashref => [ 0, { xml => 'xml' } ],
};

is( getRevision($node, ''), 0, 
 	'getRevision() should return 0 if revision is not numeric' );

$result = getRevision($node, 0);

$call = join(' ', @{ $node->{_calls}[0] }); 
like( $call, qr/^sqlSelectHashref/, 
	'... should fetch for revision from database' );

like( $call, qr/\* revision node_id=.+revision_id=.+inside_workspace=7/, 
	'... should use workspace id, if it exists' );
is( $result, 0, '... should return 0 if fetch fails' );

delete $node->{workspace};
{
	local *Everything::Node::node::xml2node;
	my @x2n;
	*Everything::Node::node::xml2node = sub {
		push @x2n, [ @_ ];
		return [{ x2n => 1 }];
	};

	my @fields = qw( node_id createtime reputation );

	@$node{ @fields } = (8) x 3;

	$result = getRevision($node, 1);

	like( join(' ', @{ $node->{_calls}[1] }), 
		qr/\* revision node_id=.+revision_id=.+inside_workspace=0/, 
		'... should use 0, with no workspace' );
	is( join(' ', @{ $x2n[0] }), 'xml noupdate', '... should xml-ify revision');

	is( $result->{x2n}, 1, '... returning the revised node' );
	is( "@$node{@fields}", "@$result{@fields}", 
		'... and should copy node_id, createtime, and reputation fields' );
}

# logRevision()
$node->{_subs} = {
	hasAccess => [ 0, (1) x 4 ],
	getId => [ 'id' ],
	getNode => [ $node, $node ],
	sqlSelect => [ 0, [ 2, 1, 4 ], 0, [] ],
};
$node->{_calls} = [];

is( logRevision($node, 'user'), 0, 
	'logRevision() should return 0 if user lacks write access' );
is( join(' ', @{ $node->{_calls}[0] }), 'hasAccess user w',
	'... so it should check for it' );

delete $node->{DB}{workspace};
$node->{type}{maxrevisions} = 0;

$result = logRevision($node, 'user');
like( join(' ', @{ $node->{_calls}[2] }), qr/sqlDelete revision.+_id < 0/,
	'... should delete redo revisions for node if not in workspace' );
is( join(' ', @{ $node->{_calls}[4] }), 'getNode id force',
	'... and should get node' );
is( $node->{_calls}[5][0], 'toXML', '... and should XMLify it' );
is( $result, 0, '... should return 0 if lacking max revisons' );

$node->{_calls} = [];
$node->{type}{maxrevisions} = -1;
$node->{type}{derived_maxrevisions} = 1;

$result = logRevision($node, 'user');
like( join(' ', @{ $node->{_calls}[5] }), 
	qr/sqlSelect max.+revision.+node_id=.+workspace=/,
	'... should fetch max revision for node' );
like( join(' ', @{ $node->{_calls}[8] }),
	qr/sqlSelect count.+min.+max.+revision/,
	'... should fetch max, min, and total revisions' );
like( join(' ', @{ $node->{_calls}[9] }),
	qr/sqlDelete revision.+revision_id=1 /,
	'... should delete oldest revision if in workspace and at max limit' );
is( join(' ', @{ $node->{_calls}[7] }[0, 1]), 'sqlInsert revision',
	'... and should insert new revision' );
is( $node->{_calls}[7][2]{revision_id}, 1,
	'... using revision id of 1 if necessary' );
is( $result, 4, '... should return id of newest revision' );

$node->{workspace}{node_id} = $node->{node_id} = 44;
$node->{workspace}{nodes}{44} = 'R';

$node->{_calls} = [];
logRevision($node, 'user');
like( join(' ', @{ $node->{_calls}[1] }),
	qr/sqlDelete revision.+_id=44.+_id > R/,
	'... should undo later revisions if in workspace' );
is( $node->{_calls}[2][0], 'toXML',
	'... and should XMLify node for workspace' );

# undo()
# 23
$node->{workspace} = $node;
$node->{_subs} = {
	hasAccess => [ 0, (1) x 7 ],
	sqlSelectMany => [ ($node) x 6 ],
	fetchrow => [ (1, 5, 0) x 6 ],
};
is( undo($node, 'uS'), 0, 'undo() should return 0 if user lacks write access' );
is( join(' ', @{ $node->{_calls}[-1] }), 'hasAccess uS w',
	'... so it should check for it' );

$node->{node_id} = 13;
delete $node->{workspace}{nodes}{13};
is( undo($node, ''), 0,
	'... should return 0 unless workspace contains this node' );

$node->{_calls} = [];
my $position = \$node->{workspace}{nodes}{13};
$$position = 4;
$result = undo($node, 'user', 1, 1);

like( join(' ', @{ $node->{_calls}[1] }), 
	qr/^sqlSelectMany revision_id revision node_id=13.+_workspace=/,
	'... should fetch revision_ids for node in workspace' );

is( $result, 1, 
	'... should return true if testing/redoing and revision exists for pos');
is( undo($node, 'user', 0, 1), 1,
	'... or if undoing and position is one or more' );

$$position = 0;
is( undo($node, 'user', 0, 0), 0, '... otherwise false' );

$$position = 1;
is( undo($node, 'user', 1, 0), 0,
	'... should return false if redoing and revision does not exist for pos' );

$$position = 0;
is( undo($node, 'user', 0, 0), 0,
	'... or if undoing and position is not one or more' );

$$position = 1;
$result = undo($node, 'user', 0, 0);
is( $node->{workspace}{nodes}{13}, 0,
	'... should update position in workspace for node' );
is( join(' ', @{ $node->{_calls}[-2] }), "setVars $node->{workspace}{nodes}",
	'... should set variables in workspace' );
is( join(' ', @{ $node->{_calls}[-1] }), 'update user',
	'... and update workspace' );
ok( $result, '... returning true' );

delete $node->{workspace};
$node->{_calls} = [];

my $rev = {};
$node->{_subs} = {
	hasAccess => [ (1) x 6 ],
	sqlSelectHashref => [ 0, ($rev) x 5 ],
};

$result = undo($node, 'user', 0, 0);
like( join(' ', @{ $node->{_calls}[1] }), 
	qr/sqlSelectHashref.+_id=13.+BY rev.+DESC/,
	'... if not in workspace, should fetch revision for node' );
ok( ! $result, '... should return false unless found' );

$rev->{revision_id} = 1;
ok( ! undo($node, 'user', 1), 
	'... or false if redoing and revision_id is positive' );

$rev->{revision_id} = 0;
ok( ! undo($node, 'user', 1), '... or zero' );

$rev->{revision_id} = -1;
ok( ! undo($node, 'user', 0), 
	'... or false if undoing and revision_id is negative' );

$rev->{revision_id} = 77;
ok( undo($node, 'user', 0, 1), '... or true if testing' );

{
	local *Everything::Node::node::xml2node;
	*Everything::Node::node::xml2node = sub {[]};
	$result = undo($node, 'user');
}
is( $node->{_calls}[-2][0], 'toXML', '... should XMLify node');
is( $rev->{revision_id}, -77, '... should invert revision' );
like( join(' ', @{ $node->{_calls}[-1] }),
	qr/sqlUpdate revision HASH.+_id=13.+id=77$/,
	'... should update database with new revision' );

# canWorkspace()
my $ws = $node->{type} = { canworkspace => 1};

ok( Everything::Node::node::canWorkspace($node), 
	'canWorkspace() should return true if nodetype can be workspaced' );

$ws->{canworkspace} = 0;
ok( ! canWorkspace($node), '... and false if it cannot' );

$ws->{canworkspace} = -1;
$ws->{derived_canworkspace} = 0;
ok( ! canWorkspace($node), '... or false if inheriting and parent cannot' );
$ws->{derived_canworkspace} = 1;
ok( canWorkspace($node), '... and true if inheriting and parent can workspace');

# getWorkspaced()
$node->{_subs} = {
	canWorkspace => [ 0, 1, 1, 1 ],
	getRevision => [ 'rev', 0 ],
};
ok( ! getWorkspaced($node), 
	'getWorkspaced() should return unless node can be workspaced' );
$node->{node_id} = 77;
$node->{workspace} = {
	nodes => { 
		77 => 44,
		88 => 11,
	},
	cached_nodes => {
		'77_44' => 88,
	},
};
is( getWorkspaced($node), 88, 
	'... should return cached node version if it exists' );
$node->{node_id} = 88;

$result = getWorkspaced($node);
is( join(' ', @{ $node->{_calls}[-1] }), 'getRevision 11', 
	'... should fetch revision' );
is( $result, 'rev', '... returning it if it exists' );
is( $node->{workspace}{cached_nodes}{'88_11'}, 'rev','... and should cache it');

$node->{node_id} = 4;
ok( ! getWorkspaced($node), '... or false otherwise' );

# updateWorkspaced()
$node->{_subs} = {
	canWorkspace => [ 0, 1 ],
	logRevision => [ 17 ],
};
ok( ! updateWorkspaced($node),
	'updateWorkspaced() should return false unless node can be workspaced' );

$node->{_calls} = [];
$node->{workspace} = $node;
$node->{cache} = $node;
$node->{node_id} = 41;
$result = updateWorkspaced($node, 'user');
is( join(' ', @{ $node->{_calls}[1] }), 'logRevision user',
	'... should log revision' );
is( $node->{workspace}{nodes}{41}, 17, '... should log revision in workspace' );

is( join(' ', @{ $node->{_calls}[2] }), "setVars $node->{workspace}{nodes}",
	'... should update variables for workspace' );
is( join(' ', @{ $node->{_calls}[3] }), 'update user',
	'... and should update workspace node' );

is( join(' ', @{ $node->{_calls}[4] }), "removeNode $node",
	'... should remove node from cache' );
is( $result, 41, '... and should return node_id' );

sub AUTOLOAD {
    return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::Node::node::$AUTOLOAD";

	if (defined &{ $sub }) {
		*{ $AUTOLOAD } = \&{ $sub };
		goto &{ $sub };
	}
}
