package Everything::Test::NodeBase;

use strict;
use warnings;

use base 'Test::Class';

use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;

use Scalar::Util 'blessed';

sub module_class
{
	my $self =  shift;
	my $name =  blessed( $self );
	$name    =~ s/Test:://;
	return $name;
}

sub startup :Test( startup => 3 )
{
	my $self   = shift;
	my $module = $self->module_class();
	use_ok( $module ) or exit;

	can_ok( $module, 'new' );

	$self->reset_mock_nb();

	isa_ok( $self->{nb}, $module );
}

sub make_fixture :Test( setup )
{
	my $self    = shift;
	my $storage = Test::MockObject->new();
	$self->reset_mock_nb();

	$self->{storage}     = $storage;
	$self->{nb}{storage} = $storage;
	$self->{errors}      = [];
}

sub reset_mock_nb
{
	my $self   = shift;
	my $module = $self->module_class();

	my $mock_db = Test::MockObject->new();
	$mock_db->set_false(qw( getNodeByIdNew getNodeByName ))
			->set_true(qw( databaseConnect buildNodetypeModules ))
			->fake_module( 'Everything::DB::fake_db', 'new', sub { $mock_db });

	my $nb      = $module->new( '', 0, 'fake_db' );
	$self->{nb} = Test::MockObject::Extends->new( $nb );
}

sub test_new
{
	# check $db param
	# check presence of NodeCache
	# check dbname
	# check staticNodetypes field
	# check storage
	# check nodetypeModules
	# check if setting type exists
	#	- check cache settings
	#	- check cache size
}

BEGIN
{
	for my $method (qw(
		buildNodetypeModules getDatabaseHandle sqlDelete sqlSelect
		sqlSelectJoined sqlSelectMany sqlSelectHashref sqlUpdate sqlInsert
		_quoteData sqlExecute getNodeByIdNew getNodeByName constructNode
		selectNodeWhere getNodeCursor countNodeMatches getAllTypes
		dropNodeTable quote genWhereString
	))
	{
		eval <<"		END_SUB";
		sub test_$method :Test( 3 )
		{
			my \$self    = shift;
			my \$nb      = \$self->{nb};
			my \$storage = \$self->{storage};

			\$storage->set_always( $method => 'proxied_$method' );
			can_ok( \$nb, '$method' );

			my \$result = \$nb->$method();

			is( \$storage->next_call(), '$method',
				'$method should proxy to storage method' );
			is( \$result, 'proxied_$method', '... returning result' );
		}
		END_SUB
	}
}

sub test_get_type :Test( 9 )
{
	my $self = shift;
	my $nb   = $self->{nb};

	is( $nb->getType(), undef,
		'getType() should return unless passed a node thing' );

	is( $nb->getType( '' ), undef, '... or if it is empty' );

	my $mock_node = Test::MockObject::Extends->new( 'Everything::Node' );

	is( $nb->getType( $mock_node ), $mock_node,
		'... returning node if it is a node' );
	
	$nb->set_series( getNode => 'name', 'id' );
	
	is( $nb->getType( 'name' ), 'name',
		'... returning fetched node, if named' );
	
	my ( $method, $args ) = $nb->next_call();
	is( join( '-', @$args ), "$nb-name-1", '... by name for nodetype' );
	
	is( $nb->getType( 12345 ), 'id',
		'... returning node for positive node_id' );
	
	( $method, $args ) = $nb->next_call();
	is( join( '-', @$args ), "$nb-12345", '... by id alone' );
	
	is( $nb->getType(  0 ), undef, '... returning nothing for zero id' );
	is( $nb->getType( -1 ), undef, '... or for negative node_id' );
}

1;
__END__

can_ok( $package, 'getAllTypes' );
my @list = ( 1 .. 3 );
$mock_storage->set_series( sqlSelectMany => undef, $mock_storage )
	->mock( fetchrow => sub { return shift @list if @list; return; } )
	->set_series( getNode => 'a', 'b', 'c' )
	->set_true('finish')
	->clear();

ok( !getAllTypes($mock), 'getAllTypes() should return without a cursor' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'sqlSelectMany', '... selecting several rows' );
is(
	join( '-', @$args ),
	"$mock_storage-node_id-node-type_nodetype=1",
	'... node_ids of nodetype nodes from node table'
);
my @result = getAllTypes($mock);
is_deeply( \@result, [qw( a b c )], '... returning fetched nodes in order' );

can_ok( $package, 'getFields' );
$mock->set_always( getFieldsHash => 'gfh' )->clear();

$result = getFields( $mock, 'table' );

( $method, $args ) = $mock->next_call();
is( $method, 'getFieldsHash', 'getFields() should call getFieldsHash()' );
is( join( '-', @$args ), "$mock-table-0", '... passing table name' );
is( $result, 'gfh', '... returning results' );

can_ok( $package, 'dropNodeTable' );
{
	local *Everything::printLog;
	my @log;
	*Everything::printLog = sub {
		push @log, [@_];
	};

	# lots of nodroppables, but testing them all is tedious
	ok( !dropNodeTable( $mock, 'container' ),
		'dropNodeTable() should fail if attempting to drop core table' );
	like( $le[0][1], qr/core table 'container'!/, '... logging an error' );

	$mock_storage->set_series( tableExists => 0, 1 )
		->set_always( genTableName => 'tname' )
		->set_always( do => 'done' )
		->clear();

	ok( !dropNodeTable( $mock, 'zapit' ), '... failing unless table exists' );

	( $method, $args ) = $mock_storage->next_call();
	is( $method, 'tableExists', '... so should check' );
	is( $args->[1], 'zapit', '... with passed table name' );

	$mock_storage->{dbh} = $mock_storage;

	$result = dropNodeTable( $mock, 'zapit' );
	like(
		$log[0][0],
		qr/Dropping table 'zapit'/,
		'... should log the drop, if attempted'
	);

	( $method, $args ) = $mock_storage->next_call(2);
	is( $method, 'genTableName', '... generating table name' );
	is( $args->[1], 'zapit', '... from passed name' );

	( $method, $args ) = $mock_storage->next_call();
	is( $method, 'do', '... performing a SQL call' );
	is( $args->[1], 'drop table tname', '... dropping table' );

	is( $result, 'done', '... returning result' );
}

can_ok( $package, 'quote' );
$mock_storage->set_always( quote => 'quoted' )->clear();
$result = quote( $mock, 'quoteme' );

( $method, $args ) = $mock_storage->next_call();
is( $method,    'quote',   'quote() should call DB quote()' );
is( $args->[1], 'quoteme', '... on passed string' );
is( $result,    'quoted',  '... returning results' );

# this interface sucks.  Really sucks.
can_ok( $package, 'getRef' );

$mock->set_series( getNode => 'first', 'second', 'not third' )->clear();

my ( $first, $second, $third, $u ) = ( 1, 2, bless {}, 'Everything::Node' );
$result = getRef( $mock, $first, $second, $third, $u );
is( $first,  'first',  'getRef() should modify references in place' );
is( $second, 'second', '... for all passed in node_ids' );
ok( $third->isa( 'Everything::Node' ), '... not mangling existing nodes' );
is( $u, undef, '... skipping undefined values' );
is( $result, 'first', '... returning node of first element' );

can_ok( $package, 'getId' );
is( getId(), undef, 'getId() should return without node id' );
my $node = bless { node_id => 11 }, 'Everything::Node';
is( getId( $mock, $node ), 11,  '... returning node_id of node, if provided' );
is( getId( $mock, 12 ),    12,  '... or node_id, if a number' );
is( getId( $mock, -13 ),   -13, '... or an integer' );
is( getId( $mock, 'foo' ), undef, '... but undef not an integer' );

can_ok( $package, 'hasPermission' );
$mock->set_series( getNode => 0, { code => 'return 1' } )->clear();
{
	local *Everything::Security::checkPermissions;

	my @cp;
	*Everything::Security::checkPermissions = sub {
		push @cp, [@_];
		return 'cp';
	};

	$result = hasPermission( $mock, 'u', 'p', 'm' );

	( $method, $args ) = $mock->next_call();
	is( $method, 'getNode', 'checkPermission() should fetch permission node' );
	is( join( '-', @$args ),
		"$mock-p-permission", '... by identifier and type' );
	is( $result, 0, '... returning false without that node' );

	$result = hasPermission( $mock, 'u', 'p', 'm' );
	is( @cp, 1, '... should check permissions with a perm node' );
	is( join( '-', @{ $cp[0] } ),
		'1-m', '... with permissions results and mode' );
	is( $result, 'cp', '... returning results' );
}

can_ok( $package, 'joinWorkspace' );
can_ok( $package, 'joinWorkspace' );
can_ok( $package, 'buildNodetypeModules' );

$mock_storage->set_series( sqlSelectMany => 0, $mock_storage )
	->set_series( fetchrow_array     => qw( user nodetype blah ) )
	->set_series( loadNodetypeModule => 1, 1, 0 );

is( buildNodetypeModules($mock), undef,
	'buildNodetypeModules() should return with no database cursor' );

is_deeply(
	buildNodetypeModules($mock),
	{ "Everything::Node::user" => 1, "Everything::Node::nodetype" => 1 },
	'... returning a hashref of available nodetype names'
);

can_ok( $package, 'loadNodetypeModule' );
ok(
	loadNodetypeModule( $mock, 'Everything::NodeBase' ),
	'loadNodetypeModule() should return true if module is loaded'
);

@le = ();
ok( loadNodetypeModule( $mock, 'Everything::Node::user' ),
	'... or if module can be loaded' );
ok( !loadNodetypeModule( $mock, 'Everything::Node::blah' ),
	'... but false if it cannot' );

can_ok( $package, 'getNode' );

my ( @ennew, $ennew );
$mock->set_always( getNodeByIdNew => { title => 'node by id' } )
	->fake_new( "Everything::Node" => sub { push @ennew, [@_]; $ennew } );
$mock->clear();

$ennew = { node_id => 11 };

isnt( getNode( $mock, 0 ),
	undef, 'getNode() should return node zero given node_id of 0' );

exit;

can_ok( $package, 'getNodeByName' );
can_ok( $package, 'getNodeByIdNew' );
can_ok( $package, 'constructNode' );
can_ok( $package, 'getNodeCursor' );
can_ok( $package, 'genWhereString' );
can_ok( $package, 'getNodetypeTables' );

can_ok( $package, 'rebuildNodetypeModules' );
$mock->set_always( 'buildNodetypeModules', 'bntm' );
$mock->{nodetypeModules} = '';
rebuildNodetypeModules($mock);
is( $mock->call_pos(-1), 'buildNodetypeModules',
	'rebuildNodetypeModules() should call buildNodetypeModules' );
is( $mock->{nodetypeModules}, 'bntm', '... caching results' );

can_ok( $package, 'resetNodeCache' );
$mock->set_true('resetCache')->{cache} = $mock;
$mock->{storage}{cache} = $mock;
resetNodeCache($mock);
is( $mock->call_pos(-1), 'resetCache',
	'resetNodeCache() should call resetCache() on cache' );

can_ok( $package, 'getDatabaseHandle' );
$mock_storage->{dbh} = 'dbh';
is( getDatabaseHandle($mock), 'dbh', 'getDatabaseHandle() should return dbh' );

can_ok( $package, 'getCache' );
$mock->{cache} = 'cache';
$mock->{storage}{cache} = 'cache';
is( getCache($mock), 'cache', 'getCache() should return cache' );

can_ok( $package, 'newNode' );
$mock->set_always( 'getType', 'gt' )->set_always( 'getNode', 'gn' )->clear();

$result = newNode( $mock, 'type', 'title' );

( $method, $args ) = $mock->next_call();
is( $method, 'getType', 'newNode() should fetch nodetype node' );
is( $args->[1], 'type', '... for the requested nodetype' );

( $method, $args ) = $mock->next_call();
is( $method, 'getNode', '... calling getNode()' );
is( join( '-', @$args[ 1, 2 ] ),
	'title-gt', '... with title and nodetype node' );
is( $args->[3], 'create force', '... forcing node creation' );

newNode( $mock, '' );

( $method, $args ) = $mock->next_call(2);
like( $args->[1], qr/^dummy\d+/,
	'... using a dummy title if none is provided' );

can_ok( $package, 'getNodeZero' );
$mock->{nodezero} = 'ZERO';
is( getNodeZero($mock), 'ZERO',
	'getNodeZero() should return cached node if it exists' );
delete $mock->{nodezero};
my $zero = {};
$mock->set_series( 'getNode', $zero, 'author_user' )->clear();
$result = getNodeZero($mock);
is( $result, $zero, '... and should cache node if it must be created' );

( $method, $args ) = $mock->next_call();
is( $method, 'getNode', '... fetching a node' );
is( join( '-', @$args ), "$mock-/-location-create force",
	'... forcing creation of the root location' );

( $method, $args ) = $mock->next_call();
is( $method, 'getNode', '... fetching another node' );
is( join( '-', @$args ), "$mock-root-user", '... the root user' );
is_deeply(
	$zero,
	{
		node_id     => 0,
		author_user => 'author_user',
		guestaccess => '-----',
		otheraccess => '-----',
		groupaccess => '-----',
	},
	'... and zero node attributes should be set correctly'
);
is( $mock->{nodezero}, $result, '... and node should be cached' );

can_ok( $package, 'getNodeWhere' );
$mock->set_series( 'selectNodeWhere', undef, 'foo', [ 1 .. 5 ] )
	->set_series( 'getNode', 0, 2, 0, 4, 5 )->clear();

my @expected = qw( where type orderby limit offset reftotalrows );
$result = getNodeWhere( $mock, @expected );

( $method, $args ) = $mock->next_call();
is( $method, 'selectNodeWhere',
	'getNodeWhere() should delegate to selectNodeWhere()' );
is(
	join( '-', @$args ),
	join( '-', $mock, @expected ),
	'... passing most args'
);
is( $result, undef, '... returning if it fails' );
is( getNodeWhere($mock), undef, '... or if it does not return a listref' );
$result = getNodeWhere( $mock, @expected );
is_deeply(
	$result,
	[ 2, 4, 5 ],
	'... fetching and returning a list ref of nodes'
);

can_ok( $package, 'sqlDelete' );
$mock->{storage}     = $mock_storage;
$mock_storage->{dbh} = $mock_storage;
ok( !sqlDelete( $mock ),
	'sqlDelete() should return false with no where clause' );

$mock_storage->set_always( 'genTableName', 'table name' )
	->set_always( 'prepare', $mock_storage )
	->set_always( 'execute', 'executed' )
	->clear();

$result = sqlDelete( $mock, 'table', 'clause', [ 'one', 'two' ] );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'genTableName', '... generating correct table name' );
is( $args->[1], 'table', '... passing the passed table name' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'prepare', '... preparing a SQL call' );
is( $args->[1], 'DELETE FROM table name WHERE clause',
	'... with the generated name and where clause' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'execute', '... executing a SQL call' );
is( join( '-', @$args ), "$mock_storage-one-two", '... with any bound arguments' );
sqlDelete( $mock, 1, 2 );
$mock_storage->called_args_string_is( -1, '-', "$mock_storage",
	'... or an empty list with no bound args' );
is( $result, 'executed', '... returning the result of the execution' );

can_ok( $package, 'sqlSelect' );
my @frargs = ( [], ['one'], [ 'two', 'three' ] );
$mock_storage->set_series( 'sqlSelectMany', undef, ($mock_storage) x 3 )
	         ->mock( 'fetchrow', sub { return @{ shift @frargs } } )
			 ->set_true('finish')
			 ->clear();

$result = sqlSelect( $mock, 1 .. 10 );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'sqlSelectMany', 'sqlSelect() should call sqlSelectMany()' );
is( join( '-', @$args ), "$mock_storage-1-2-3-4-5-6-7-8-9-10",
	'... passing all args' );
ok( !$result, '... returning false if call fails' );

ok( !sqlSelect($mock), '... or if no rows are selected' );
is_deeply( sqlSelect($mock), 'one', '... one item if only one is returned' );
is_deeply(
	sqlSelect($mock),
	[ 'two', 'three' ],
	'... and a list reference if many'
);

can_ok( $package, 'sqlSelectJoined' );
$mock_storage->set_always( 'genTableName', 'gentable' )
	         ->set_series( 'prepare', ($mock_storage) x 2, 0 )
			 ->set_series( 'execute', 1, 0 )
			 ->clear();

my $joins = { one => 1, two => 2 };
$result = sqlSelectJoined( $mock, 'select', 'table', $joins, 'where', 'other',
	'bound', 'values' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'genTableName', 'sqlSelectJoined() should generate table name' );
is( $args->[1], 'table', '... if provided' );

for my $join ( keys %$joins )
{
	( $method, $args ) = $mock_storage->next_call();
	is( $method, 'genTableName', '... and genTable name' );
	is( $args->[1], $join, '... for each joined table' );
}

( $method, $args ) = $mock_storage->next_call();
is( $method, 'prepare', '... preparing a SQL call' );
like( $args->[1], qr/SELECT select/, '... selecting the requested columns' );
like( $args->[1], qr/FROM gentable/,
	'... from the generated table name if supplied' );
like( $args->[1], qr/LEFT JOIN gentable ON 1/,
	'... left joining joined tables' );
like( $args->[1], qr/LEFT JOIN gentable ON 2/, '... as necessary' );
like( $args->[1], qr/WHERE where/, '... adding the where clause if present' );
like( $args->[1], qr/other/,       '... and the other clause' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'execute', '... executing the query' );
is( join( '-', @$args ), "$mock_storage-bound-values",
	'... with bound values' );

is( $result, $mock_storage, '... returning the cursor if it executes' );
$result = sqlSelectJoined( $mock, 'select' );
is( $result, undef, '... or undef otherwise' );

( $method, $args ) = $mock_storage->next_call(1);
is( $method, 'prepare', '... not joining tables if they are not present' );
is( $args->[1], 'SELECT select ',
	'... nor any table, where, or other clauses unless requested' );
ok( !sqlSelectJoined( $mock, 'select' ),
	'... returning false if prepare fails' );

can_ok( $package, 'sqlSelectMany' );
$mock_storage->set_always( 'genTableName', 'gentable' )
			 ->set_series( 'prepare', 0, ($mock_storage) x 5 )
			 ->set_series( 'execute', (0) x 3, 1 )
			 ->unmock( 'sqlSelectMany' )
			 ->clear();

$result = sqlSelectMany( $mock, 'sel' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'prepare', 'sqlSelectMany() should prepare a SQL statement' );
is( $args->[1], 'SELECT sel ', '... with the selected fields' );
sqlSelectMany( $mock, 'sel', 'tab' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'genTableName', '... generating a table name, if passed' );

is( ( $mock_storage->next_call() )[1]->[1], 'SELECT sel FROM gentable ',
	'... using it in the SQL statement' );
sqlSelectMany( $mock, 'sel', '', 'whe' );

is( ( $mock_storage->next_call(2) )[1]->[1], 'SELECT sel WHERE whe ',
	'... adding a where clause if needed' );
sqlSelectMany( $mock, 'sel', '', '', 'oth' );

is( ( $mock_storage->next_call(2) )[1]->[1], 'SELECT sel oth',
	'... and an other clause as necessary' );
ok( !$result, '... returning false if prepare fails' );
is( sqlSelectMany( $mock, '' ), $mock_storage,
	'... the cursor if it succeeds' );
$mock_storage->called_args_string_is( -1, '-', "$mock_storage",
	'... using no bound values by default' );
sqlSelectMany( $mock, ('') x 4, [ 'hi', 'there' ] );
$mock_storage->called_args_string_is( -1, '-', "$mock_storage-hi-there",
	'... or any bounds passed' );

can_ok( $package, 'sqlSelectHashref' );
$mock_storage->set_series( 'sqlSelectMany', 0, $mock_storage )
			 ->set_always( 'fetchrow_hashref', 'hash' )
			 ->set_true('finish')
			 ->clear();

$result = sqlSelectHashref( $mock, 'foo', 'bar', 'baz', 'quux', 'qiix' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'sqlSelectMany',
	'sqlSelectHashref() should call sqlSelectMany()' );
is( join( '-', @$args ), "$mock_storage-foo-bar-baz-quux-qiix",
	'... passing all args' );
ok( !$result, '... returning false if that fails' );
is( sqlSelectHashref($mock), 'hash', '... or a fetched hashref on success' );

is( $mock_storage->next_call(3), 'finish',
	'... finishing the statement handle' );

can_ok( $package, 'sqlUpdate' );
$mock_storage->mock( _quoteData => sub {
	[ 'n', 'm', 's' ], [ '?', 1, 8 ], ['foo']
	} )
	->set_always( 'genTableName', 'gentable' )
	->set_always( 'sqlExecute',   'executed' )
	->clear();

ok( !sqlUpdate( $mock, 'table', {} ),
	'sqlUpdate() should return false without update data' );

my $data = { foo => 'bar' };
$result  = sqlUpdate( $mock, 'table', $data );

( $method, $args ) = $mock_storage->next_call();
is( $method, '_quoteData', '... quoting data, if present' );
is( $args->[1], $data, '... passing in the data argument' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'genTableName', '... quoting the table name' );
is( $args->[1], 'table', '... passing in the table argument' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'sqlExecute', '... and should execute query' );
is( $args->[1], "UPDATE gentable SET n = ?,\nm = 1,\ns = 8",
	'... with names and values quoted appropriately' );
is_deeply( $args->[2], ['foo'], '.. and bound args as appropriate' );

$mock->clear();
sqlUpdate( $mock, 'table', $data, 'where clause' );

( $method, $args ) = $mock_storage->next_call(3);
like( $args->[1], qr/\nWHERE where clause\n/m,
	'... adding the where clause as necessary' );

can_ok( $package, 'sqlInsert' );

$data   = { foo => 'bar' };
$result = sqlInsert( $mock, 'table', $data );

( $method, $args ) = $mock_storage->next_call();
is( $method, '_quoteData', 'sqlInsert() should quote data, if present' );
is( $args->[1], $data, '... passing in the data argument' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'genTableName', '... quoting the table name' );
is( $args->[1], 'table', '... passing in the table argument' );

( $method, $args ) = $mock_storage->next_call();
is( $method, 'sqlExecute', '... and should execute query' );
is( $args->[1], "INSERT INTO gentable (n, m, s) VALUES(?, 1, 8)",
	'... with names and values quoted appropriately' );
is_deeply( $args->[2], ['foo'], '.. and bound args as appropriate' );

can_ok( $package, '_quoteData' );
$mock_storage->unmock( '_quoteData' );

my ( $names, $values, $bound ) =
	$mock_storage->_quoteData( { foo => 'bar', -baz => 'quux' } );
is( join( '|', sort @$names ),
	'baz|foo', '_quoteData() should remove leading minus from names' );
ok( ( grep { /quux/ } @$values ), '... treating unquoted values literally' );
ok( ( grep { /\?/, } @$values ), '... and using placeholders for quoted ones' );
is( join( '|', @$bound ), 'bar', '... returning quoted values in bound arg' );

can_ok( $package, 'sqlExecute' );
{
	my $log;

	local *Everything::printLog;
	*Everything::printLog = sub { $log = shift };

	$mock_storage->set_series( 'prepare', $mock_storage, 0 )
				 ->set_always( 'execute', 'success' )
				 ->unmock( 'sqlExecute' )
				 ->clear();

	$result = sqlExecute( $mock, 'sql here', [ 1, 2, 3 ] );

	( $method, $args ) = $mock_storage->next_call();
	is( $method, 'prepare', 'sqlExecute() should prepare a statement' );
	is( $args->[1], 'sql here', '... with the passed in SQL' );

	( $method, $args ) = $mock_storage->next_call();
	is( $method, 'execute', '... executing the statement' );
	is( join( '-', @$args ), "$mock_storage-1-2-3",
		'... with bound variables' );
	is( $result, 'success', '... returning the results' );

	@le = ();
	ok( !sqlExecute( $mock, 'bad', [ 6, 5, 4 ] ), '... or false on failure' );
	is( $le[0][1], "SQL failed: bad [6 5 4]\n",
		'... logging SQL and bound values as error' );
}
