package Everything::Node::Test::node;

use strict;
use warnings;

use base 'Test::Class';

use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;

use Scalar::Util 'reftype';

sub node_class { 'Everything::Node::node' }

my $module = 'Everything::Node::node';

sub startup :Test( startup => 5 )
{
	my $self         = shift;
	my $mock         = Test::MockObject->new();
	$self->{mock_db} = $mock;
	$self->{errors}  = \(my @le);

	$mock->fake_module( 'Everything', logErrors => sub { push @le, [@_] } );
	*Everything::Node::node::DB = \$mock;

	my $module = $self->node_class();
	my %import;

	my $mockimport = sub { $import{ +shift }++ };

	for my $mod (qw( DBI Everything Everything::NodeBase Everything::XML))
	{
		$mock->fake_module( $mod, import => $mockimport );
	}

	use_ok( $module ) or exit;
	is( keys %import, 4, "$module should use several modules" );

	ok( $module->isa( 'Everything::Node' ),
		"$module should extend Everything::Node" );

	# now test that C<new()> works
	can_ok( $module, 'new' );
	isa_ok( $module->new(), $module );
}

sub test_dbtables :Test( 2 )
{
	my $self   = shift;
	my $module = $self->node_class();
	can_ok( $module, 'dbtables' );
	my @tables = $module->dbtables();
	is_deeply( \@tables, [ 'node' ], 'dbtables() should return node tables' );
}

sub make_fixture :Test(setup)
{
	my $self      = shift;
	$self->{mock} = Test::MockObject->new();
	my $node      = $self->node_class()->new();
	$self->{node} = Test::MockObject::Extends->new( $node );
}

sub test_construct :Test( 1 )
{
	my $self = shift;
	ok( $self->{node}->construct(), 'construct() should return true' );
}

sub test_destruct :Test( 1 )
{
	my $self = shift;
	ok( $self->{node}->destruct(), 'destruct() should return true' );
}

sub test_insert_access :Test( 3 )
{
	my $self = shift;
	my $mock = $self->{mock};
	my $node = $self->{node};

	$node->set_false( 'hasAccess' );
	is( $node->insert( $mock ), 0,
		'insert() should return 0 if user lacks access' );

	my ($method, $args) = $node->next_call();
	is( $args->[1], $mock, 'checking for correct user' );
	is( $args->[2], 'c',   '... and create access' );
}

sub test_insert_restrictions :Test( 2 )
{
	my $self = shift;
	my $mock = $self->{mock};
	my $node = $self->{node};

	$node->set_true( 'hasAccess' )
		 ->set_series( restrictTitle => 0, 1 );
	is( $node->insert( $mock ), 0,
		'insert() should return 0 if node title is restricted' );

	$node->{node_id} = 5;
	is( $node->insert( $mock ), 5,
		'insert() should return node_id if it is positive already' );
}

sub test_insert_restrict_dupes :Test( 2 )
{
	my $self               = shift;
	my $node               = $self->{node};
	my $db                 = $self->{mock_db};
	$node->{node_id}       = 0;
	$node->{type}          = $node;
	$node->{restrictdupes} = 1;
	$node->{DB}            = $db;
	$node->set_true(qw( hasAccess restrictTitle getId ))
		 ->set_always( getTableArray => [] );
	$db->set_series( sqlSelect => 1, 0 )
	   ->set_always( getFields => 'none' )
	   ->set_always( now => '' )
	   ->set_always( getNode => undef )
	   ->set_true( 'sqlInsert' )
	   ->set_always( lastValue => 100 );

	is( $node->insert( '' ), 0,
		'insert() should return 0 if dupes are restricted and exist' );

	$node->{restrictdupes} = 0;

	is( $node->insert( '' ), 100,
		'... or should return the inserted node_id otherwise' );
}

sub test_is_group :Test( 1 )
{
	ok( ! shift->{node}->isGroup(), 'isGroup() should return false' );
}

sub test_get_field_datatype :Test( 3 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->{a_field} = 111;
	is( $node->getFieldDatatype( 'a_field' ), 'noderef',
		'getFieldDatatype() should mark node references as "noderef"' );

	$node->{b_field} = 'foo';
	$node->{cfield}  = 112;
	is( $node->getFieldDatatype( 'b_field' ), 'literal_value',
		'... but references without ids are literal' );
	is( $node->getFieldDatatype( 'bfield' ), 'literal_value',
		'... and so are fields without underscores' );
}

sub test_has_vars :Test( 1 )
{
	ok( !shift->{node}->hasVars(), 'hasVars() should return false' );
}

# clone()
sub test_clone :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};
	is( $self->node_class->clone(), undef,
		'clone() should return without a node to clone' );
	is( $node->clone( 'foo' ), undef, '... or a node hash' );

	# now set a field not to overwrite
	$node->{node_id} = 1;

	my $from_hash =
	{
		test          => 'test',
		node_id       => 2,
		type          => "don't copy",
		title         => "don't copy",
		createtime    => "don't copy",
		type_nodetype => "don't copy",
	};

	ok( $node->clone( $from_hash ),	
		'clone() should return true with proper args' );

	is_deeply( $node, { %$node, test => 'test', node_id => 1 },
		'clone() should copy only necessary fields' );
}

sub test_commit_xml_fixes :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_true( 'update' );
	$node->commitXMLFixes();

	my ( $method, $args ) = $node->next_call();
	is( "$method @$args", "update $node -1 nomodify",
		'commitXMLFixes() should call update() on node' );
}

sub test_restrict_title :Test( 6 )
{
	my $self = shift;
	my $node = $self->{node};
	delete $node->{title};

	ok( ! $node->restrictTitle(),
		'restrictTitle() called with no title field should return false' );

	$node->{title} = '[foo]';
	ok( ! $node->restrictTitle(),
		'... or if title contains a square bracket'
	);

	$node->{title} = 'f>o<o';
	ok( ! $node->restrictTitle(), '... or an angle bracket' );

	my $errors;
	{
		local *Everything::logErrors;
		*Everything::logErrors = sub { $errors = shift };
		$node->{title} = 'o|o';
		ok( ! $node->restrictTitle(), '... or a pipe' );
	}
	like( $errors, qr/node.+invalid characters/, '... and should log error' );

	$node->{title} = 'a good name zz9';
	ok( $node->restrictTitle(), '... but should return true otherwise' );
}

sub test_get_node_keep_keys :Test( 10 )
{
	my $self = shift;
	my $node = $self->{node};

	my $result = $node->getNodeKeepKeys();
	is( reftype( $result ), 'HASH',
		'getNodeKeepKeys() should return a hash reference' );

	for my $class (qw( author group other guest ))
	{
		ok( exists $result->{"${class}access"},
			"... and should contain $class access" );
		ok( exists $result->{"dynamic${class}_permission"},
			"... and $class permission keys" );
	}
	ok( exists $result->{loc_location}, '... and location key' );
}

sub test_get_node_keys :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};

	my %keys = map { $_ => 1 }
		qw( createtime modified hits reputation
		lockedby_user locktime lastupdate foo_id bar );

	$node->set_always( getNodeDatabaseHash => \%keys );

	my $result = $node->getNodeKeys();

	is( $node->next_call(), 'getNodeDatabaseHash',
		'getNodeKeys() should fetch node database keys' );
	is( keys %$result, 9,
		'... and should return them unchanged, if not exporting' );

	$result = $node->getNodeKeys( 1 );
	ok( ! exists $result->{foo_id}, '... returning no uid keys if exporting' );
	is( join( ' ', keys %$result ), 'bar',
		'... and removing non-export keys as well' );
}

sub test_field_to_XML :Test( 5 )
{
	my $self = shift;
	my $node = $self->{node};
	my @gbt;

	local *Everything::Node::node::genBasicTag;

	*Everything::Node::node::genBasicTag = sub {
		push @gbt, [@_];
		return 'tag';
	};

	$node->{afield} = 'thisfield';
	is( $node->fieldToXML( $node, 'afield' ), 'tag',
		'fieldToXML() should return an XML tag element' );
	is( @gbt, 1, '... and should call genBasicTag()' );
	is( join( ' ', @{ $gbt[0] } ), "$node field afield thisfield",
		'... with the correct arguments' );

	ok( ! $node->fieldToXML( $node, 'notafield' ),
		'... and should return false if field does not exist' );
	ok( ! exists $node->{notafield}, '... and should not create field' );
}

sub test_get_identifying_fields :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};
	is( $node->getIdentifyingFields(), undef,
		'getIdentifyingFields() should return undef' );
}

sub test_update_from_import :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->set_true( 'update' )
		 ->set_series( -getNodeKeys => { foo => 1, bar => 2, baz => 3 } )
		 ->set_series( -getNodeKeepKeys => { bar => 1 } );

	$node->updateFromImport( { foo => 1, bar => 2, baz => 3 }, 'user' );

	is( $node->{foo} + $node->{baz}, 4,
		'getNodeKeys() should merge node keys' );

	ok( ! exists $node->{bar}, '... but not those it should keep' );
	my ( $method, $args ) = $node->next_call();
	is( "$method @$args", "update $node user nomodify",
		'... and should update node' );
	is( $node->{modified}, 0, '... setting "modified" to 0' );
}

sub test_xml_final :Test( 6 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_series( existingNodeMatches => $node, 0 )
		 ->set_true('updateFromImport')
		 ->set_true('insert');

	my $result = $node->xmlFinal();

	is( $node->next_call(), 'existingNodeMatches',
		'xmlFinal() should check for a matching node' );

	my ( $method, $args ) = $node->next_call();
	is( $method, 'updateFromImport', '... updating node if so' );
	is( join( '+', @$args ), "$node+$node+-1", '... for node by superuser' );
	is( $result, $node->{node_id}, '... returning the node_id' );

	$result = $node->xmlFinal();

	( $method, $args ) = $node->next_call(2);
	is( "$method $args->[1]", 'insert -1', '... or should insert the node' );
	is( $result, $node->{node_id}, '... returning the new node_id' );
}

sub test_conflicts_with :Test( 4 )
{
	my $self          = shift;
	my $node          = $self->{node};
	$node->{modified} = '';

	ok( ! $node->conflictsWith(),
		'conflictsWith() should return false with no digit in "modified"' );

	$node->{modified} = 1;

	my $keep     = { foo => 1 };
	my $conflict = { foo => 1, bar => 2 };

	$node->set_series( getNodeKeys => $node, $node )
		->set_series( getNodeKeepKeys => $keep, {} );

	$node->{foo} = 1;
	$node->{bar} = 3;

	my $result = $node->conflictsWith( $conflict );
	my ( $method, $args ) = $node->next_call();

	ok( $result, '... but should return true if any node field conflicts' );

	$node->{bar} = 2;
	ok( ! $node->conflictsWith( $conflict ), '... false otherwise' );

	$node->{foo} = 2;
	ok( ! $node->conflictsWith( $conflict ),
		'... and should ignore keepable keys' );
}

sub test_verify_field_update :Test( 3 )
{
	my $self = shift;
	my $node = $self->{node};
	my @fields;

	for my $field (qw(
		createtime node_id type_nodetype hits loc_location reputation
		lockedby_user locktime authoraccess groupaccess otheraccess guestaccess
		dynamicauthor_permission dynamicgroup_permission
		dynamicother_permission dynamicguest_permission
	))
	{
		push @fields, $field unless $node->verifyFieldUpdate( $field );
	}

	is( @fields, 16,
		'verifyFieldUpdate() should return false for unmodifiable fields' );
	ok( ! $node->verifyFieldUpdate( 'foo_id' ), '... and for _id fields' );
	ok( $node->verifyFieldUpdate( 'agoodkey' ),
		'... but true for everything else' );
}

__END__
	$node->{getNode} = [ { key => 'value' } ];
	$node->{foo}     = 11;

	delete $node->{type}{restrictdupes};
	$node->set_true('hasAccess')->set_list( getFields => 'foo' )
		->set_always( getTableArray => ['table'] )->set_series( getNode => 0, {} )
		->set_always( sqlSelect => 87 )->set_true('sqlInsert')
		->set_always( now => 'now' )->set_always( lastValue => 'lastValue' )
		->set_true('cache')->clear();
}

__END__
$mock->{node_id} = 0;
ok(
	defined( $result = insert( $mock, 'user' ) ),
	'... but should return node_id if no dupes exist'
);

( $method, $args ) = $mock->next_call(6);
is( $method, 'sqlInsert', '... inserting base node' );

is( $args->[1], 'node', '... into the node table' );
is_deeply(
	$args->[2],
	{
		-createtime => 'now',
		author_user => 'user',
		hits        => 0,
		foo         => 11,
	},
	'... with the proper fields'
);

is( $mock->next_call(), 'lastValue',     '... fetching node id' );
is( $mock->next_call(), 'getTableArray', '... and node tables' );
is( $mock->next_call(), 'getFields',     '... and table fields' );

( $method, $args ) = $mock->next_call();
is( $method, 'sqlInsert', '... inserting node' );
is( $args->[1], 'table', '... into proper table' );
is_deeply(
	$args->[2],
	{ foo => 11, table_id => 'lastValue' },
	'... proper fields'
);

( $method, $args ) = $mock->next_call();
is( $method, 'getNode', '... fetching node' );
is( join( '-', @$args ), "$mock-lastValue-force", '... forcing refresh' );
is( $mock->next_call(), 'cache', '... and caching node' );

# update()
$mock->{node_id} = 87;
$mock->set_series( hasAccess => 0, 1, 1 )
	->set_series( updateWorkspaced => 77, 0 )->clear()
	->set_true( -canWorkspace );

is( update( $mock, 'user' ),
	0, 'update() should return 0 if user lacks write access' );
( $method, $args ) = $mock->next_call();
is( $method, 'hasAccess', '... so should check access' );
is( join( '-', @$args ), "$mock-user-w", '... write access for user' );

$mock->{workspace}{nodes}{ $mock->{node_id} } = 1;
$mock->{DB}                                   = $mock;
$mock->{cache}                                = $mock;
$result = update( $mock, 'user' );

( $method, $args ) = $mock->next_call(2);
is( $method, 'updateWorkspaced',
	'... should update workspaced node if it is workspaced' );
is( $args->[1], 'user', '... for user' );
is( $result, 77, '... and should return the id if it that works' );

delete $mock->{workspace};
$mock->{type} = $mock;
$mock->{boom} = 88;
$mock->{foom} = 99;

$mock->set_always( getTableArray => [ 'table', 'table2' ] )
	->set_series( getFields => 'boom', 'foom' )
	->set_true('incrementGlobalVersion')->set_true('sqlUpdate')->clear();

update( $mock, 'user' );
is( $mock->next_call(2), 'incrementGlobalVersion',
	'... incrementing global version in cache' );
is( $mock->next_call(), 'cache', '... caching node' );

$method = $mock->next_call();
is( $mock->next_call(), 'sqlSelect',
	'... updating modified field without flag' );
is( $method, 'now', '... with current time' );
is( $mock->next_call(), 'getTableArray', '... fetching type tables' );

( $method, $args ) = $mock->next_call();
is( $method, 'getFields', '... fetching thte fields' );
is( $args->[1], 'table', '... of each table' );

( $method, $args ) = $mock->next_call();
is( "$method $args->[1]", 'sqlUpdate table', '... updating each table' );
is( keys %{ $args->[2] }, 1,                 '... with only allowed fields' );
is( $args->[3],           'table_id = ?',    '... for table' );
is_deeply( $args->[4], [ $mock->{node_id} ], '... with node id' );

# nuke()
$mock->set_series( hasAccess => 0, 1 )
	->set_series( isGroupType => 0, 'table1', 'table2' )
	->set_series( sqlSelectMany => 0, $mock )
	->set_always( getTableArray => ['deltable'] )->set_always( getId => 'id' )
	->set_series( fetchrow => 'group' )->set_series( sqlDelete => (1) x 4 )
	->set_true('getRef')->set_true('finish')->set_true('removeNode')->clear();

$result = nuke( $mock, 'user' );

( $method, $args ) = $mock->next_call();
is( "$method $args->[1]",
	'getRef user', 'nuke() should fetch user node unless it is -1' );
ok( !$result, '... and should return false if user lacks delete access' );

( $method, $args ) = $mock->next_call();
is( $method, 'hasAccess', '... and should check for access' );
is( join( '-', @$args ), "$mock-user-d", '... delete access for user' );

$mock->{dbh} = $mock;
$mock->clear();
{
	my $gat;
	$mock->mock( getAllTypes => sub { $gat++; return ($mock) x 3 } );
	$result = nuke( $mock, -1 );
	ok( $gat, '... should get all nodetypes' );
	$mock->set_false('getAllTypes');
}

isnt( $mock->next_call(), 'getRef',
	'... and should not get user node if it is -1' );
( $method, $args ) = $mock->next_call(2);
is( $method, 'sqlDelete', '... should delete links' );
is(
	join( '-', @$args[ 1, 2 ] ),
	'links-to_node=? OR from_node=?',
	'... should delete from or to links from links table'
);
is_deeply( $args->[3], [ 'id', 'id' ], '... with bound node id' );

( $method, $args ) = $mock->next_call();
is( $method, 'sqlDelete', '... and deleting node revisions' );
is(
	join( '-', @$args[ 1, 2 ] ),
	'revision-node_id = ?',
	'... by id from revision'
);
is_deeply( $args->[3], [87], '... with node_id' );

is( $mock->next_call(2), 'isGroupType',
	'... should check each type is a group node' );

( $method, $args ) = $mock->next_call(2);
is( $method, 'sqlSelectMany', '... should check for node' );
is(
	join( '-', @$args[ 1 .. 3 ] ),
	'table1_id-table1-node_id = ?',
	'... in group table'
);
is_deeply( $args->[5], [87], '... by node_id' );

is( $mock->next_call(3), 'fetchrow',
	'... if it exists, should fetch all containing groups' );
( $method, $args ) = $mock->next_call(3);
is( $method, 'sqlDelete', '... and should delete' );
is(
	join( '-', @$args[ 1 .. 2 ] ),
	'table2-node_id = ?',
	'... from table on node_id'
);
is_deeply( $args->[3], [87], '... for node' );

( $method, $args ) = $mock->next_call();
is( $method, 'getNode', '... fetching node' );
is( join( '-', @$args ), "$mock-group", '... for containing group' );

is( $mock->next_call(), 'incrementGlobalVersion', '... forcing a reload' );

( $method, $args ) = $mock->next_call();
is(
	"$method @$args",
	"getTableArray $mock 1",
	'... should fetch all tables for node'
);

( $method, $args ) = $mock->next_call();
is( $method, 'sqlDelete', '... deleting node' );
is( join( '-', @$args[ 1, 2 ] ), 'deltable-deltable_id = ?',
	'... from tables' );
is_deeply( $args->[3], ['id'], '... by node_id' );
is( $mock->next_call(), 'incrementGlobalVersion',
	'... should mark node as updated in cache' );

( $method, $args ) = $mock->next_call();
is( "$method @$args", "removeNode $mock $mock", '... uncaching it' );
is( $mock->{node_id}, 0, '... should reset node_id' );
ok( $result, '... and return true' );

# xmlTag()
$mock->set_series( getTagName => 'badtag', 'field', 'morefield' )->clear();

$mock->{title} = 'thistype';
my $out;
my $errors;
local *Everything::logErrors;
*Everything::logErrors = sub { (undef, $errors) = @_ };
{
	$result = xmlTag( $mock, $mock );
	is( $mock->next_call(), 'getTagName', 'xmlTag() should fetch tag name' );
	ok( !$result, '... and should return false unless it contains "field"' );
	like( $errors, qr/tag 'badtag'.+'thistype'/, '... logging an error'    );

	local *Everything::XML::parseBasicTag;
	my @pbt;
	my $parse = { name => 'parsed', parsed => 11 };
	*Everything::XML::parseBasicTag = sub {
		push @pbt, [@_];
		return $parse;
	};

	$result = xmlTag( $mock, $mock );
	is( join( ' ', @{ $pbt[0] } ), "$mock node", '... should parse tag' );
	is( $result, undef, '... should return false with no fixes' );
	is( $mock->{parsed}, 11, '... and should set node field to tag value' );

	$parse->{where} = 1;
	$result = xmlTag( $mock, $mock );
	isa_ok( $result, 'ARRAY', '... should return array ref if fixes exist' );
	is( $result->[0], $parse, '... with the fix in the array ref' );
	is( $mock->{parsed}, -1, '... setting node field to -1' );
}

# applyXMLFix()
my $where = { title => 'title', type_nodetype => 'type', field => 'b' };
my $fix   = { where => $where,  field         => 'fixme' };

is( applyXMLFix( $mock, $fix ),
	$fix, 'applyXMLFix() should return fix if it has no "fixBy" field' );

$fix->{fixBy} = 'fixme';
is( applyXMLFix( $mock, $fix, 1 ),
	$fix, '... or if the field is not set to "node"' );

$errors = '' unless defined $errors;
like(
	$errors,
	qr/handle fix by 'fixme'/, '... and should log error if flag is set'
);

$fix->{fixBy} = 'node';

my @pxw;
$mock->fake_module(
	'Everything::XML',
	patchXMLwhere => sub {
		push @pxw, [@_];
		return $_[0];
	}
);

$mock->set_series( getNode => 0, 0, { node_id => 42 } )->clear();
$errors = '';
$result = applyXMLFix( $mock, $fix );
is( $pxw[0][0], $where, '... should try to resolve node' );

( $method, $args ) = $mock->next_call();
is( $method, 'getNode', '... should fetch resolved node' );
is( join( '-', @$args[ 1, 2 ] ), "$where-type",
	'... by fix criteria for type' );

is( $result, $fix, '... returning the fix if that did not work' );
is( $errors, '', '... returning no error without flag' );

$result = applyXMLFix( $mock, $fix, 1 );
like(
	$errors,
	qr/^|Error.+find 'title' of type 'type'.+field b/,
	'... and logging an error if flag is set'
);

$result = applyXMLFix( $mock, $fix );
is( $mock->{fixme}, 42, '... should set field to found node_id' );
ok( !$result, '... should return nothing on success' );

# getRevision()
$mock->{node_id}            = 11;
$mock->{DB}                 = $mock;
$mock->{workspace}{node_id} = 7;
$mock->set_series( sqlSelect => 0, 'xml' )
	->set_series( sqlSelectHashref => 0, { xml => 'myxml' } )->clear();

is( getRevision( $mock, '' ),
	0, 'getRevision() should return 0 if revision is not numeric' );

{
	local *Everything::Node::node::xml2node;
	*Everything::Node::node::xml2node = sub { [] };
	$result = getRevision( $mock, 0 );
}

( $method, $args ) = $mock->next_call();
is( $method, 'sqlSelectHashref', '... should fetch revision from database' );

is( $args->[5][2], 7, '... using workspace id, if it exists' );
is( $result, 0, '... should return 0 if fetch fails' );

delete $mock->{workspace};
@fields = qw( node_id createtime reputation );
@$mock{@fields} = (8) x 3;
my @x2n;
{
	local *Everything::Node::node::xml2node;
	*Everything::Node::node::xml2node = sub {
		push @x2n, [@_];
		return [ { x2n => 1 } ];
	};

	$result = getRevision( $mock, 1 );
}

( $method, $args ) = $mock->next_call();
is( $method, 'sqlSelectHashref', '... should select the node revision' );
is(
	join( '-', @$args[ 1 .. 3 ], @{ $args->[5] } ),
	'*-revision-node_id = ? and revision_id = ? and inside_workspace = ?-8-1-0',
	'... using 0 with no workspace'
);
is( join( ' ', @{ $x2n[0] } ), 'myxml noupdate',
	'... should xml-ify revision' );

is( $result->{x2n}, 1, '... returning the revised node' );
is( "@$mock{@fields}", "@$result{@fields}",
	'... and should copy node_id, createtime, and reputation fields' );

# logRevision()
$mock->set_series( hasAccess => 0, (1) x 3 )->set_series( getId => 'id' )
	->set_series( getNode   => $mock )
	->set_series( sqlSelect => 0, [ 2, 1, 4 ], 0, [] )->clear();

is( logRevision( $mock, 'user' ),
	0, 'logRevision() should return 0 if user lacks write access' );
( $method, $args ) = $mock->next_call();
is( $method, 'hasAccess', '... so should check for it' );
is( join( ' ', @$args[ 1, 2 ] ), 'user w', '... write access for user' );

delete $mock->{DB}{workspace};
$mock->{type}{maxrevisions} = 0;

$result = logRevision( $mock, 'user' );
is( $result, 0, '... should return 0 if lacking max revisons' );

$mock->set_true('toXML')->set_always( getId => 1 )->clear();

$mock->{type}{maxrevisions}         = -1;
$mock->{type}{derived_maxrevisions} = 1;

$result = logRevision( $mock, 'user' );
( $method, $args ) = $mock->next_call(6);
is( $method, 'sqlSelect', '... should fetch data' );
is(
	join( '-', @$args[ 1 .. 4 ] ),
	'max(revision_id)+1-revision-node_id = ? and inside_workspace = ?-',
	'... max revision from revision table'
);
is( join( '-', @{ $args->[5] } ), '8-0', '... for node_id and workspace' );

( $method, $args ) = $mock->next_call(2);
is( "$method $args->[1]", 'sqlInsert revision', '... inserting new revision' );
is( $args->[2]{revision_id}, 1, '... using revision id of 1 if necessary' );

( $method, $args ) = $mock->next_call();
like(
	"$method @$args",
	qr/sqlSelect.+count.+min.+max.+revision/,
	'... should fetch max, min, and total revisions'
);
( $method, $args ) = $mock->next_call();
like(
	"$method @$args",
	qr/sqlDelete.+revision.+revision_id = /,
	'... should delete oldest revision if in workspace and at max limit'
);

is( $result, 4, '... should return id of newest revision' );

$mock->{workspace}{node_id} = $mock->{node_id} = 44;
$mock->{workspace}{nodes}{44} = 'R';

$mock->clear();
logRevision( $mock, 'user' );
( $method, $args ) = $mock->next_call(2);
is( $method, 'sqlDelete', '... undoing a later revision if in workspace' );
is(
	join( '-', @$args[ 1, 2 ] ),
	'revision-node_id = ? and revision_id > ? and inside_workspace = ?',
	'... by node, revision, and workspace'
);
is_deeply( $args->[3], [ 44, 'R', 44 ], '... with the correct values' );
is( $mock->next_call(), 'toXML', '... and should XMLify node for workspace' );

# undo()
$mock->{workspace} = $mock;
$mock->set_series( hasAccess => 0, (1) x 7 )
	->set_series( sqlSelectMany => ($mock) x 6 )
	->set_series( fetchrow      => ( 1, 5, 0 ) x 6 )->clear();

is( undo( $mock, 'uS' ),
	0, 'undo() should return 0 if user lacks write access' );
( $method, $args ) = $mock->next_call();
is( $method, 'hasAccess', '... so should call hasAccess()' );
is( join( '-', @$args[ 1, 2 ] ), 'uS-w', '... read access for user' );

$mock->{node_id} = 13;
delete $mock->{workspace}{nodes}{13};
is( undo( $mock, '' ),
	0, '... returning 0 unless workspace contains this node' );

$mock->set_true('setVars')->clear();
my $position = \$mock->{workspace}{nodes}{13};
$$position = 4;
$result    = undo( $mock, 'user', 1, 1 );

( $method, $args ) = $mock->next_call(2);
is( $method, 'sqlSelectMany', '... selecting many rows' );
is(
	join( '-', @$args[ 1 .. 3 ] ),
	'revision_id-revision-node_id = ? and inside_workspace = ?',
	'... should fetch revision_ids for node in workspace'
);
is_deeply( $args->[5], [ 13, 13 ], '... for node and revision id' );

is( $result, 1,
	'... should return true if testing/redoing and revision exists for pos' );
is( undo( $mock, 'user', 0, 1 ),
	1, '... or if undoing and position is one or more' );

$$position = 0;
is( undo( $mock, 'user', 0, 0 ), 0, '... otherwise false' );

$$position = 1;
is( undo( $mock, 'user', 1, 0 ),
	0,
	'... should return false if redoing and revision does not exist for pos' );

$$position = 0;
is( undo( $mock, 'user', 0, 0 ),
	0, '... or if undoing and position is not one or more' );

$$position = 1;
$mock->clear();

$result = undo( $mock, 'user', 0, 0 );
is( $mock->{workspace}{nodes}{13},
	0, '... should update position in workspace for node' );

( $method, $args ) = $mock->next_call(6);

is( $method, 'setVars', '... should set variables' );
is( $args->[1], $mock->{workspace}{nodes}, '... in workspace' );
( $method, $args ) = $mock->next_call();
is( $method, 'update', '... updating workspace' );
is( $args->[1], 'user', '... for user' );
ok( $result, '... returning true' );

delete $mock->{workspace};

my $rev = {};
$mock->set_series( hasAccess => (1) x 6 )
	->set_series( sqlSelectHashref => 0, ($rev) x 5 )->clear();

$result = undo( $mock, 'user', 0, 0 );
( $method, $args ) = $mock->next_call(2);
is( $method, 'sqlSelectHashref', '... fetching data' );
like(
	join( ' ', @$args ),
	qr/\* revision .+_id=13.+BY rev.+DESC/,
	'... if not in workspace, should fetch revision for node'
);
ok( !$result, '... should return false unless found' );

$rev->{revision_id} = 1;
ok( !undo( $mock, 'user', 1 ),
	'... or false if redoing and revision_id is positive' );

$rev->{revision_id} = 0;
ok( !undo( $mock, 'user', 1 ), '... or zero' );

$rev->{revision_id} = -1;
ok( !undo( $mock, 'user', 0 ),
	'... or false if undoing and revision_id is negative' );

$rev->{revision_id} = 77;
ok( undo( $mock, 'user', 0, 1 ), '... or true if testing' );

$mock->clear();
{
	local *Everything::Node::node::xml2node;
	*Everything::Node::node::xml2node = sub { [] };
	$result = undo( $mock, 'user' );
}
is( $mock->next_call(3), 'toXML', '... should XMLify node' );
is( $rev->{revision_id}, -77, '... should invert revision' );

( $method, $args ) = $mock->next_call();
is( $method, 'sqlUpdate', '... should update database' );
is(
	join( '-', @$args[ 1, 3 ] ),
	'revision-node_id = ? and inside_workspace = ? and revision_id = ?',
	'... with new revision'
);
is_deeply( $args->[4], [ 13, 0, 77 ], '... for node, workspace, and revision' );

# canWorkspace()
my $ws = $mock->{type} = { canworkspace => 1 };

ok( Everything::Node::node::canWorkspace($mock),
	'canWorkspace() should return true if nodetype can be workspaced' );

$ws->{canworkspace} = 0;
ok( !canWorkspace($mock), '... and false if it cannot' );

$ws->{canworkspace}         = -1;
$ws->{derived_canworkspace} = 0;
ok( !canWorkspace($mock), '... or false if inheriting and parent cannot' );
$ws->{derived_canworkspace} = 1;
ok( canWorkspace($mock),
	'... and true if inheriting and parent can workspace' );

# getWorkspaced()
$mock->set_series( canWorkspace => 0, 1, 1, 1 )
	->set_series( getRevision => 'rev', 0 )->clear();

ok( !getWorkspaced($mock),
	'getWorkspaced() should return unless node can be workspaced' );
$mock->{node_id}   = 77;
$mock->{workspace} = {
	nodes => {
		77 => 44,
		88 => 11,
	},
	cached_nodes => { '77_44' => 88, },
};
is( getWorkspaced($mock), 88,
	'... should return cached node version if it exists' );
$mock->{node_id} = 88;

$mock->clear();
$result = getWorkspaced($mock);
( $method, $args ) = $mock->next_call(2);
is( "$method $args->[1]", 'getRevision 11', '... should fetch revision' );

is( $result, 'rev', '... returning it if it exists' );
is( $mock->{workspace}{cached_nodes}{'88_11'},
	'rev', '... and should cache it' );

$mock->{node_id} = 4;
ok( !getWorkspaced($mock), '... or false otherwise' );

# updateWorkspaced()
$mock->set_series( canWorkspace => 0, 1 )->set_series( logRevision => 17 );

ok( !updateWorkspaced($mock),
	'updateWorkspaced() should return false unless node can be workspaced' );

$mock->clear();
$mock->{workspace} = $mock;
$mock->{cache}     = $mock;
$mock->{node_id}   = 41;
$result = updateWorkspaced( $mock, 'user' );
( $method, $args ) = $mock->next_call(2);
is( $method, 'logRevision', '... should log revision' );
is( $args->[1], 'user', '... for user' );
is( $mock->{workspace}{nodes}{41}, 17, '... should log revision in workspace' );

( $method, $args ) = $mock->next_call();
is(
	"$method $args->[1]",
	"setVars $mock->{workspace}{nodes}",
	'... should update variables for workspace'
);
( $method, $args ) = $mock->next_call();
is( "$method $args->[1]", 'update user', '... updating workspace node' );

( $method, $args ) = $mock->next_call();
is( "$method $args->[1]", "removeNode $mock", '... removing node from cache' );
is( $result, 41, '... and should return node_id' );
