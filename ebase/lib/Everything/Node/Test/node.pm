package Everything::Node::Test::node;

use strict;
use warnings;

use base 'Test::Class';

use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;

use Scalar::Util 'reftype';

local *Everything::Node::SUPER = \&UNIVERSAL::SUPER;
sub node_class { 'Everything::Node::node' }

sub startup :Test( startup => 3 )
{
	my $self         = shift;
	$self->{errors}  = [];

	my $mock         = Test::MockObject->new();
	$mock->fake_module( 'Everything', logErrors => sub
		{
			push @{ $self->{errors} }, [@_]
		}
	);
	*Everything::Node::node::DB = \$mock;

	my $module = $self->node_class();
	my %import;

	my $mockimport = sub { $import{ +shift }++ };

	for my $mod (qw( DBI Everything Everything::NodeBase Everything::XML))
	{
		$mock->fake_module( $mod, import => $mockimport );
	}

	use_ok( $module ) or exit;

	# now test that C<new()> works
	can_ok( $module, 'new' );
	isa_ok( $module->new(), $module );
}

sub test_extends :Test( 1 )
{
	my $self   = shift;
	my $module = $self->node_class();

	ok( $module->isa( 'Everything::Node' ),
		"$module should extend Everything::Node" );
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
	my $db        = Test::MockObject->new();
	$self->reset_mock_node();

	*Everything::Node::node::DB = \$db;
	$self->{mock_db}            = $db;
	$self->{node}{DB}           = $db;
	$self->{errors}             = [];
}

sub reset_mock_node
{
	my $self      = shift;
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
	$node->set_true(qw( -hasAccess -restrictTitle -getId ))
		 ->set_always( -getTableArray => [] );
	$db->set_series( -sqlSelect => 1, 0 )
	   ->set_always( -getFields => 'none' )
	   ->set_always( -now => '' )
	   ->set_series( -getNode => undef, { DB => $db } )
	   ->set_true( 'sqlInsert' )
	   ->set_always( -lastValue => 100 );

	is( $node->insert( '' ), 0,
		'insert() should return 0 if dupes are restricted and exist' );

	$node->{restrictdupes} = 0;

	is( $node->insert( '' ), 100,
		'... or should return the inserted node_id otherwise' );
}

sub test_insert :Test( 10 )
{
	my $self               = shift;
	my $node               = $self->{node};
	my $db                 = $self->{mock_db};
	$node->{node_id}       = 0;
	$node->{type}          = $node;
	$node->{restrictdupes} = 1;

	$node->set_true(qw( -hasAccess -restrictTitle -getId ));
	$db->set_always( getNode => { key => 'value' } )
	    ->set_always( -lastValue => 101 );
	$node->{foo}  = 11;

	delete $node->{type}{restrictdupes};
	$db->set_list( -getFields => 'foo' )
	   ->set_series( getNode => 0, {} )
	   ->set_true( 'sqlInsert' )
	   ->set_always( -now => 'now' )
	   ->clear();

	$node->set_always( -getTableArray => [ 'table' ] )
		 ->set_true( 'cache' );
	$node->{node_id} = 0;

	ok( defined $node->insert( 'user' ),
		'... but should return node_id if no dupes exist' );
	
	my ( $method, $args ) = $db->next_call( 2 );
	is( $method, 'sqlInsert', '... inserting base node' );

	is( $args->[1], 'node', '... into the node table' );
	is_deeply( $args->[2],
		{
			-createtime => 'now',
			author_user => 'user',
			hits        => 0,
			foo         => 11,
		},
		'... with the proper fields'
	);

	( $method, $args ) = $db->next_call();
	is( $method, 'sqlInsert', '... inserting node' );
	is( $args->[1], 'table', '... into proper table' );
	is_deeply( $args->[2], { foo => 11, table_id => 101 },
		'... proper fields' );

	( $method, $args ) = $db->next_call();
	is( $method, 'getNode', '... fetching node' );
	is( join( '-', @$args ), "$db-101-force", '... forcing refresh' );
	is( $node->next_call(), 'cache', '... and caching node' );
}

sub test_update_access :Test( 3 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->set_false( 'hasAccess' );
	is( $node->update( 'user' ), 0,
		'update() should return 0 if user lacks write access' );

	my ( $method, $args ) = $node->next_call();
	is( $method, 'hasAccess',                '... so should check access' );
	is( join( '-', @$args ), "$node-user-w", '... write access for user'  );
}

sub test_update :Test( 11 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->{type} = $node;
	$node->{boom} = 88;
	$node->{foom} = 99;
	$db->{cache}  = $db;

	$node->set_true( -hasAccess )
		 ->set_always( getTableArray => [ 'table', 'table2' ] )
		 ->set_true( 'cache' );

	$db->set_true(qw( incrementGlobalVersion sqlUpdate now sqlSelect ))
	   ->set_series( getFields => 'boom', 'foom' );

	$node->update( 'user' );
	is( $db->next_call(), 'incrementGlobalVersion',
		'... incrementing global version in cache' );
	is( $node->next_call(), 'cache', '... caching node' );

	my $method = $db->next_call();
	is( $db->next_call(), 'sqlSelect',
		'... updating modified field without flag' );
	is( $method, 'now', '... with current time' );
	is( $node->next_call(), 'getTableArray', '... fetching type tables' );

	( $method, my $args ) = $db->next_call();
	is( $method, 'getFields', '... fetching the fields' );
	is( $args->[1], 'table',  '... of each table' );

	( $method, $args ) = $db->next_call();
	is( "$method $args->[1]", 'sqlUpdate table', '... updating each table' );
	is( keys %{ $args->[2] }, 1,
		'... with only allowed fields' );
	is( $args->[3],           'table_id = ?',    '... for table' );
	is_deeply( $args->[4], [ $node->{node_id} ], '... with node id' );
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

	$node->{title} = 'o|o';
	ok( ! $node->restrictTitle(), '... or a pipe' );
	like( $self->{errors}[0][0], qr/node.+invalid characters/,
		'... and should log error' );

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

sub test_xml_tag :Test( 9 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( getTagName => 'badtag' );

	$node->{type}  = $node;
	$node->{title} = 'thistype';
	my $result = $node->xmlTag( $node );
	is( $node->next_call(), 'getTagName', 'xmlTag() should fetch tag name' );
	ok( !$result, '... and should return false unless it contains "field"' );
	like( $self->{errors}[0][1], qr/tag 'badtag'.+'thistype'/,
	    '... logging an error'    );

	my @pbt;
	my $parse = { name => 'parsed', parsed => 11 };

	local *Everything::XML::parseBasicTag;
	*Everything::XML::parseBasicTag = sub {
		push @pbt, [@_];
		return $parse;
	};

	$node->set_series( getTagName => 'field', 'morefield' );
	$result = $node->xmlTag( $node );
	is( join( ' ', @{ $pbt[0] } ), "$node node", '... should parse tag' );
	is( $result, undef, '... should return false with no fixes' );
	is( $node->{parsed}, 11, '... and should set node field to tag value' );

	$parse->{where} = 1;
	$result = $node->xmlTag( $node );
	isa_ok( $result, 'ARRAY', '... should return array ref if fixes exist' );
	is( $result->[0], $parse, '... with the fix in the array ref' );
	is( $node->{parsed}, -1, '... setting node field to -1' );
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

sub test_apply_xml_fix_no_fixby_node :Test( 3 )
{
	my $self = shift;
	my $node = $self->{node};

	my $where = { title => 'title', type_nodetype => 'type', field => 'b' };
	my $fix   = { where => $where,  field         => 'fixme', title => '' };

	is( $node->applyXMLFix( $fix ), $fix,
		'applyXMLFix() should return fix if it has no "fixBy" field' );

	$fix->{fixBy} = 'fixme';
	is( $node->applyXMLFix( $fix, 1 ), $fix,
		'... or if the field is not set to "node"' );

	like( $self->{errors}[0][1],
		qr/handle fix by 'fixme'/, '... and should log error if flag is set' );
}

sub test_apply_xml_fix :Test( 8 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	my $where = { title => 'title', type_nodetype => 'type',  field => 'b' };
	my $fix   = { where => $where,  field         => 'fixme', fixBy => 'node' };

	my @pxw;
	$node->fake_module(
		'Everything::XML',
		patchXMLwhere => sub {
			push @pxw, [@_];
			return $_[0];
		}
	);

	$db->set_series( getNode => 0, 0, { node_id => 42 } );
	@{ $self->{errors} } = ();
	my $result = $node->applyXMLFix( $fix );
	is( $pxw[0][0], $where, '... should try to resolve node' );

	my ( $method, $args ) = $db->next_call();
	is( $method, 'getNode', '... should fetch resolved node' );
	is( join( '-', @$args[ 1, 2 ] ), "$where-type",
		'... by fix criteria for type' );

	is( $result, $fix,           '... returning the fix if that did not work' );
	is( @{ $self->{errors}[0] }, 0, '... returning no error without flag' );

	$node->{title}       = 'n_title';
	$node->{type}{title} = 't_title';
	$result = $node->applyXMLFix( $fix, 1 );
	like( $self->{errors}[1][1],
		qr/Unable.+find 'title' of type 'type'.+'fixme'.+'n_title'.+'t_title'/s,
		'... and logging an error if flag is set' );

	$result = $node->applyXMLFix( $fix );
	is( $node->{fixme}, 42, '... should set field to found node_id' );
	ok( !$result, '... should return nothing on success' );
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

sub test_get_revision :Test( 9 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->{node_id}          = 11;
	$db->{workspace}{node_id} =  7;
	$db->set_series( sqlSelect => 0, 'xml' )
		->set_series( sqlSelectHashref => 0, { xml => 'myxml' } );

	is( $node->getRevision( '' ), 0,
		'getRevision() should return 0 if revision is not numeric' );

	$node->set_always( xml2node => [] );
	my $result = $node->getRevision( 0 );

	my ( $method, $args ) = $db->next_call();
	is( $method, 'sqlSelectHashref', '... should fetch revision from database' );

	is( $args->[5][2], 7, '... using workspace id, if it exists' );
	is( $result, 0, '... should return 0 if fetch fails' );

	delete $db->{workspace};
	my @fields = qw( node_id createtime reputation );
	@$node{@fields} = (8) x 3;

	{
		local *Everything::Node::node::xml2node;
		*Everything::Node::node::xml2node = sub { $node->xml2node( @_ ) };
		$node->set_always( xml2node => [ { x2n => 1 } ] );
		$result = $node->getRevision( 1 );
	}

	( $method, $args ) = $db->next_call();
	is( $method, 'sqlSelectHashref', '... should select the node revision' );
	is( join( '-', @$args[ 1 .. 3 ], @{ $args->[5] } ),
		'*-revision-node_id = ? and revision_id = ? and inside_workspace = ?-8-1-0',
		'... using 0 with no workspace' );

	( $method, $args ) = $node->next_call();
	is( join( ' ', @$args ), "$node myxml noupdate",
		'... should xml-ify revision' );

	is( $result->{x2n}, 1, '... returning the revised node' );
	is( "@$node{@fields}", "@$result{@fields}",
		'... and should copy node_id, createtime, and reputation fields' );
}

sub test_log_revision_access :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};
	$node->set_false( 'hasAccess' );
	is( $node->logRevision( 'user' ), 0,
		'logRevision() should return 0 if user lacks write access' );
}

sub test_log_revision :Test( 13 )
{
	my $self         = shift;
	my $node         = $self->{node};
	my $db           = $self->{mock_db};
	$node->{node_id} = 99;
	
	$node->set_series( -hasAccess => (1) x 3 )
		 ->set_series( getId => 'id' )
		 ->set_true( 'canWorkspace' );

	$db->set_always( -getNode   => $node )
	   ->set_series( sqlSelect => 0, [ 2, 1, 4 ], 0, [ 0 ] )
	   ->set_true(qw( sqlDelete sqlInsert ));

	$node->{type}{maxrevisions} = 0;

	my $result = $node->logRevision( 'user' );
	is( $result, 0, 'logRevisions() should return 0 if lacking max revisons' );

	$node->set_true( 'toXML' )
		 ->set_always( -getId => 1 );

	$node->{type}{maxrevisions}         = -1;
	$node->{type}{derived_maxrevisions} = 1;

	$result = $node->logRevision( 'user' );
	my ( $method, $args ) = $db->next_call( 2 );
	is( $method, 'sqlSelect', '... should fetch data' );
	is( join( '-', @$args[ 1 .. 4 ] ),
		'max(revision_id)+1-revision-node_id = ? and inside_workspace = ?-',
		'... max revision from revision table'
	);
	is( join( '-', @{ $args->[5] } ), '99-0', '... for node_id and workspace' );

	( $method, $args ) = $db->next_call();
	is( "$method $args->[1]", 'sqlInsert revision',
		'... inserting new revision' );
	is( $args->[2]{revision_id}, 1, '... using revision id of 1 if necessary' );

	( $method, $args ) = $db->next_call();
	like( "$method @$args", qr/sqlSelect.+count.+min.+max.+revision/,
		'... should fetch max, min, and total revisions' );
	( $method, $args ) = $db->next_call();
	like( "$method @$args", qr/sqlDelete.+revision.+revision_id = /,
		'... should delete oldest revision if in workspace and at max limit' );

	is( $result, 4, '... should return id of newest revision' );

	$db->{workspace}{node_id}   = $node->{node_id} = 44;
	$db->{workspace}{nodes}{44} = 'R';

	$db->clear();
	$node->logRevision( 'user' );
	( $method, $args ) = $db->next_call();
	is( $method, 'sqlDelete', '... undoing a later revision if in workspace' );
	is( join( '-', @$args[ 1, 2 ] ),
		'revision-node_id = ? and revision_id > ? and inside_workspace = ?',
		'... by node, revision, and workspace' );
	is_deeply( $args->[3], [ 44, 'R', 44 ], '... with the correct values' );
	is( $node->next_call(), 'toXML', '... XMLifying node for workspace' );
}

sub test_undo_access :Test()
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_false( 'hasAccess' );

	is( $node->undo( 'uS' ), 0,
		'undo() should return 0 if user lacks write access' );
}

sub test_undo :Test( 27 )
{
	local *Everything::Node::node::ISA;
	*Everything::Node::node::ISA = [];

	my $self         = shift;
	my $node         = $self->{node};
	my $db           = $self->{mock_db};
	$node->{node_id} = 13;
	$db->{workspace} = $node;
	$db->{cache}     = $node;

	$node->set_true(qw( -hasAccess update toXML ));
	$db->set_series( sqlSelectMany => ($db) x 6 )
	   ->set_series( -fetchrow     => ( 1, 5, 0 ) x 6 )
	   ->set_true( 'sqlUpdate' );

	is( $node->undo( $node, '' ), 0,
		'undo() should return 0 unless workspace contains this node' );

	$node->set_true( 'setVars' );

	my $position = \$db->{workspace}{nodes}{13};
	$$position   = 4;
	my $result   = $node->undo( 'user', 1, 1 );

	my ( $method, $args ) = $db->next_call();
	is( $method, 'sqlSelectMany', '... selecting many rows' );
	is(
		join( '-', @$args[ 1 .. 3 ] ),
		'revision_id-revision-node_id = ? and inside_workspace = ?',
		'... should fetch revision_ids for node in workspace'
	);
	is_deeply( $args->[5], [ 13, 13 ], '... for node and revision id' );

	is( $result, 1,
		'... returning true if testing/redoing and revision exists for pos' );
	is( $node->undo( 'user', 0, 1 ), 1,
		'... or if undoing and position is one or more' );

	$$position = 0;
	is( $node->undo( 'user', 0, 0 ), 0, '... otherwise false' );

	$$position = 1;
	is( $node->undo( 'user', 1, 0 ), 0,
		'... returning false if redoing and revision does not exist for pos' );

	$$position = 0;
	is( $node->undo( 'user', 0, 0 ), 0,
		'... or if undoing and position is not one or more' );

	$$position = 1;

	$result = $node->undo( 'user', 0, 0 );
	is( $db->{workspace}{nodes}{13}, 0,
		'... should update position in workspace for node' );

	( $method, $args ) = $node->next_call();

	is( $method, 'setVars', '... should set variables' );
	is( $args->[1], $db->{workspace}{nodes}, '... in workspace' );
	( $method, $args ) = $node->next_call();
	is( $method, 'update',  '... updating workspace' );
	is( $args->[1], 'user', '... for user' );
	ok( $result,            '... and returning true' );

	delete $db->{workspace};

	my $rev = {};
	$db->set_series( sqlSelectHashref => 0, ($rev) x 5 )
	   ->clear();

	$result = $node->undo( 'user', 0, 0 );
	( $method, $args ) = $db->next_call();
	is( $method, 'sqlSelectHashref', '... fetching data' );
	like( join( ' ', @$args ), qr/\* revision .+_id=13.+BY rev.+DESC/,
		'... if not in workspace, should fetch revision for node' );
	ok( !$result, '... should return false unless found' );

	$rev->{revision_id} = 1;
	ok( ! $node->undo( 'user', 1 ),
		'... or false if redoing and revision_id is positive' );

	$rev->{revision_id} = 0;
	ok( ! $node->undo( 'user', 1 ), '... or zero' );

	$rev->{revision_id} = -1;
	ok( ! $node->undo( 'user', 0 ),
		'... or false if undoing and revision_id is negative' );

	$rev->{revision_id} = 77;
	ok( $node->undo( 'user', 0, 1 ), '... or true if testing' );

	$node->clear();
	$db->clear();
	{
		local *Everything::Node::node::xml2node;
		*Everything::Node::node::xml2node = sub { [] };
		$result = $node->undo( 'user' );
	}
	is( $node->next_call(), 'toXML', '... should XMLify node' );
	is( $rev->{revision_id}, -77, '... should invert revision' );

	( $method, $args ) = $db->next_call( 2 );
	is( $method, 'sqlUpdate', '... should update database' );
	is( join( '-', @$args[ 1, 3 ] ),
		'revision-node_id = ? and inside_workspace = ? and revision_id = ?',
		'... with new revision' );
	is_deeply( $args->[4], [ 13, 0, 77 ], '... for node, workspace, and revision' );
}

sub test_can_workspace :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};
	my $ws   = $node->{type} = { canworkspace => 1 };

	ok( $node->canWorkspace(),
		'canWorkspace() should return true if nodetype can workspace' );

	$ws->{canworkspace} = 0;
	ok( ! $node->canWorkspace(), '... and false if it cannot' );

	$ws->{canworkspace}         = -1;
	$ws->{derived_canworkspace} = 0;
	ok( ! $node->canWorkspace(),
		'... or false if inheriting and parent cannot' );
	$ws->{derived_canworkspace} = 1;
	ok( $node->canWorkspace(),
		'... and true if inheriting and parent can workspace' );
}

sub test_get_workspaced :Test( 6 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->set_series( -canWorkspace => 0, 1, 1, 1 )
		 ->set_series( getRevision   => 'rev', 0 );

	ok( ! $node->getWorkspaced(),
		'getWorkspaced() should return unless node can be workspaced' );
	$node->{node_id}   = 77;
	$db->{workspace} =
	{
		nodes =>
		{
			77 => 44,
			88 => 11,
		},
		cached_nodes => { '77_44' => 88, },
	};
	is( $node->getWorkspaced(), 88,
		'... should return cached node version if it exists' );
	$node->{node_id} = 88;

	my $result = $node->getWorkspaced();
	my ( $method, $args ) = $node->next_call();
	is( "$method $args->[1]", 'getRevision 11', '... should fetch revision' );

	is( $result, 'rev', '... returning it if it exists' );
	is( $db->{workspace}{cached_nodes}{'88_11'},
		'rev', '... and should cache it' );

	$node->{node_id} = 4;
	ok( !$node->getWorkspaced(), '... or false otherwise' );
}

sub test_update_workspaced :Test( 8 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->set_series( -canWorkspace => 0, 1 )
		 ->set_series( logRevision  => 17 )
		 ->set_true(qw( setVars update removeNode ));

	ok( ! $node->updateWorkspaced(),
		'updateWorkspaced() should return false unless node can workspace' );

	$db->{workspace} = $node;
	$db->{cache}     = $node;
	$node->{node_id} = 41;
	my $result       = $node->updateWorkspaced( 'user' );

	my ( $method, $args ) = $node->next_call();
	is( $method, 'logRevision', '... should log revision' );
	is( $args->[1], 'user', '... for user' );
	is( $db->{workspace}{nodes}{41}, 17, '... logging revision in workspace');

	( $method, $args ) = $node->next_call();
	is( "$method $args->[1]", "setVars $db->{workspace}{nodes}",
		'... updating variables for workspace' );
	( $method, $args ) = $node->next_call();
	is( "$method $args->[1]", 'update user', '... updating workspace node' );

	( $method, $args ) = $node->next_call();
	is( "$method $args->[1]", "removeNode $node",
		'... removing node from cache' );
	is( $result, 41, '... and should return node_id' );
}

sub test_nuke_access :Test( 4 )
{
	my $self    = shift;
	my $node    = $self->{node};
	my $db      = $self->{mock_db};
	$node->set_false( 'hasAccess' );
	$db->set_true( 'getRef' );

	my $result = $node->nuke( 'user' );

	my ( $method, $args ) = $db->next_call();
	is( "$method $args->[1]",
		'getRef user', 'nuke() should fetch user node unless it is -1'   );
	ok( !$result,      '... returning false if user lacks delete access' );

	( $method, $args ) = $node->next_call();
	is( $method, 'hasAccess', '... and should check for access' );
	is( join( '-', @$args ), "$node-user-d", '... delete access for user' );
}

sub test_nuke :Test( 27 )
{
	my $self         = shift;
	my $node         = $self->{node};
	my $db           = $self->{mock_db};
	$node->{type}    = $node;
	$db->{cache}     = $db;
	$node->{node_id} = 89;

	$node->set_true( 'hasAccess' )
		->set_series( isGroupType => 0, 'table1', 'table2' )
	    ->set_always( getTableArray => [ 'deltable' ] )
		->set_always( -getId => 'id' );
	$db->set_true(qw( getRef finish removeNode incrementGlobalVersion ))
	   ->set_always( getNode => $db )
	   ->set_series( sqlSelectMany => 0, $db )
	   ->set_series( fetchrow => 'group' )
	   ->set_series( sqlDelete => (1) x 4 );

	my $result;
	{
		my $gat;
		$db->mock( getAllTypes => sub { $gat++; return ($node) x 3 } );
		$result = $node->nuke( -1 );
		ok( $gat, '... should get all nodetypes' );
		$db->set_false( 'getAllTypes' );
	}

	isnt( $node->next_call(), 'getRef',
		'... and should not get user node if it is -1' );
	my ( $method, $args ) = $db->next_call();
	is( $method, 'sqlDelete', '... should delete links' );
	is( join( '-', @$args[ 1, 2 ] ), 'links-to_node=? OR from_node=?',
		'... should delete from or to links from links table' );
	is_deeply( $args->[3], [ 'id', 'id' ], '... with bound node id' );

	( $method, $args ) = $db->next_call();
	is( $method, 'sqlDelete', '... and deleting node revisions' );
	is( join( '-', @$args[ 1, 2 ] ), 'revision-node_id = ?',
		'... by id from revision' );
	is_deeply( $args->[3], [89], '... with node_id' );

	is( $node->next_call(), 'isGroupType',
		'... should check each type is a group node' );

	( $method, $args ) = $db->next_call(2);
	is( $method, 'sqlSelectMany', '... should check for node' );
	is( join( '-', @$args[ 1 .. 3 ] ), 'table1_id-table1-node_id = ?',
		'... in group table' );
	is_deeply( $args->[5], [89], '... by node_id' );

	is( $db->next_call(3), 'fetchrow',
		'... if it exists, should fetch all containing groups' );
	( $method, $args ) = $db->next_call( 2 );
	is( $method, 'sqlDelete', '... and should delete' );
	is( join( '-', @$args[ 1 .. 2 ] ), 'table2-node_id = ?',
		'... from table on node_id' );
	is_deeply( $args->[3], [89], '... for node' );

	( $method, $args ) = $db->next_call();
	is( $method, 'getNode', '... fetching node' );
	is( join( '-', @$args ), "$db-group", '... for containing group' );

	is( $db->next_call(), 'incrementGlobalVersion', '... forcing a reload' );

	( $method, $args ) = $node->next_call( 3 );
	is( "$method @$args", "getTableArray $node 1",
		'... should fetch all tables for node' );

	( $method, $args ) = $db->next_call();
	is( $method, 'sqlDelete', '... deleting node' );
	is( join( '-', @$args[ 1, 2 ] ), 'deltable-deltable_id = ?',
		'... from tables' );
	is_deeply( $args->[3], ['id'], '... by node_id' );
	is( $db->next_call(), 'incrementGlobalVersion',
		'... should mark node as updated in cache' );

	( $method, $args ) = $db->next_call();
	is( "$method @$args", "removeNode $db $node", '... uncaching it' );
	is( $node->{node_id}, 0, '... should reset node_id' );
	ok( $result, '... and return true' );
}

1;
