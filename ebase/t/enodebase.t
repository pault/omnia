#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use strict;
use vars qw( $AUTOLOAD );

use Test::More tests => 87;
use Test::MockObject;

# temporarily avoid sub redefined warnings
my $mock = Test::MockObject->new();
$mock->fake_module( 'Everything' );

my $package = 'Everything::NodeBase';

sub AUTOLOAD
{
	$AUTOLOAD =~ s/main:://;
	if (my $sub = $package->can( $AUTOLOAD ))
	{
		no strict 'refs';
		*{ $AUTOLOAD} = $sub;
		goto &$AUTOLOAD;
	}
}

use_ok( $package );

my ($result, $method, $args);

can_ok( $package, 'sqlDelete' );
$mock->{dbh} = $mock;
ok( ! sqlDelete(), 'sqlDelete() should return false with no where clause' );

$mock->set_always( 'genTableName', 'table name' )
	 ->set_always( 'prepare', $mock )
	 ->set_always( 'execute', 'executed' );

$result = sqlDelete( $mock, 'table', 'clause', [ 'one', 'two' ]);
($method, $args) = $mock->next_call();
is( $method, 'genTableName', '... generating correct table name' );
is( $args->[1], 'table', '... passing the passed table name' );
($method, $args) = $mock->next_call();
is( $method, 'prepare', '... preparing a SQL call' );
is( $args->[1], 'DELETE FROM table name WHERE clause',
	'... with the generated name and where clause' );
($method, $args) = $mock->next_call();
is( $method, 'execute', '... executing a SQL call' );
is( join('-', @$args), "$mock-one-two", '... with any bound arguments' );
sqlDelete( $mock, 1, 2 );
$mock->called_args_string_is( -1, '-', "$mock",
	'... or an empty list with no bound args' );
is( $result, 'executed', '... returning the result of the execution' );

can_ok( $package, 'sqlSelect' );
my @frargs = ([], [ 'one' ], [ 'two', 'three' ]);
$mock->clear()
	 ->set_series( 'sqlSelectMany', undef, ($mock) x 3 )
	 ->mock( 'fetchrow',  sub { return @{ shift @frargs } } )
	 ->set_true( 'finish' );

$result = sqlSelect( $mock, 1 .. 10);
($method, $args) = $mock->next_call();
is( $method, 'sqlSelectMany', 'sqlSelect() should call sqlSelectMany()' );
is(join('-', @$args), "$mock-1-2-3-4-5-6-7-8-9-10", '... passing all args');
ok( ! $result, '... returning false if call fails' );

ok( ! sqlSelect( $mock ), '... or if no rows are selected' );
is_deeply( sqlSelect( $mock ), 'one', '... one item if only one is returned' );
is_deeply( sqlSelect( $mock ), [ 'two', 'three' ],
	'... and a list reference if many' );

can_ok( $package, 'sqlSelectJoined' );
$mock->clear()
	->set_always( 'genTableName', 'gentable' )
	->set_series( 'prepare', ($mock) x 2, 0 )
	->set_series( 'execute', 1, 0 );

my $joins = { one => 1, two => 2 };
$result = sqlSelectJoined( $mock, 'select', 'table', $joins, 'where', 'other',
	'bound', 'values' );

($method, $args) = $mock->next_call();
is( $method, 'genTableName', 'sqlSelectJoined() should generate table name' );
is( $args->[1], 'table', '... if provided' );

foreach my $join (keys %$joins)
{
	($method, $args) = $mock->next_call();
	is( $method, 'genTableName', '... and genTable name' );
	is( $args->[1], $join, '... for each joined table' );
}

($method, $args) = $mock->next_call();
is( $method, 'prepare', '... preparing a SQL call' );
like( $args->[1], qr/SELECT select/, '... selecting the requested columns' );
like( $args->[1], qr/FROM gentable/,
	'... from the generated table name if supplied' );
like( $args->[1], qr/LEFT JOIN gentable ON 1/,
	'... left joining joined tables' );
like( $args->[1], qr/LEFT JOIN gentable ON 2/, '... as necessary' );
like( $args->[1], qr/WHERE where/, '... adding the where clause if present' );
like( $args->[1], qr/other/, '... and the other clause' );

($method, $args) = $mock->next_call();
is( $method, 'execute', '... executing the query' );
is( join('-', @$args), "$mock-bound-values", '... with bound values' );

is( $result, $mock, '... returning the cursor if it executes' );
$result = sqlSelectJoined( $mock, 'select' );
is( $result, undef, '... or undef otherwise' );
($method, $args) = $mock->next_call(1);
is( $method, 'prepare', '... not joining tables if they are not present' );
is( $args->[1], 'SELECT select ',
	'... nor any table, where, or other clauses unless requested' );
ok( ! sqlSelectJoined( $mock, 'select' ),
	'... returning false if prepare fails' );

can_ok( $package, 'sqlSelectMany' );
$mock->clear()
	 ->set_always( 'genTableName', 'gentable' )
	 ->set_series( 'prepare', 0, ($mock) x 5 )
	 ->set_series( 'execute', (0) x 3, 1 );

$result = sqlSelectMany( $mock, 'sel' );
($method, $args) = $mock->next_call();
is( $method, 'prepare', 'sqlSelectMany() should prepare a SQL statement' );
is( $args->[1], 'SELECT sel ', '... with the selected fields' );
sqlSelectMany( $mock, 'sel', 'tab' );
($method, $args) = $mock->next_call();
is( $method, 'genTableName', '... generating a table name, if passed' );
is( ( $mock->next_call() )[1]->[1], 'SELECT sel FROM gentable ',
	'... using it in the SQL statement' );
sqlSelectMany( $mock, 'sel', '', 'whe' );
is( ( $mock->next_call( 2 ) )[1]->[1], 'SELECT sel WHERE whe ',
	'... adding a where clause if needed' );
sqlSelectMany( $mock, 'sel', '', '', 'oth' );
is( ( $mock->next_call( 2 ) )[1]->[1], 'SELECT sel oth',
	'... and an other clause as necessary' );
ok( ! $result, '... returning false if prepare fails' );
is( sqlSelectMany( $mock, '' ), $mock, '... the cursor if it succeeds' );
$mock->called_args_string_is( -1, '-', "$mock",
	'... using no bound values by default' );
sqlSelectMany( $mock, ('') x 4, [ 'hi', 'there' ] );
$mock->called_args_string_is( -1, '-', "$mock-hi-there",
	'... or any bounds passed' );

can_ok( $package, 'sqlSelectHashref' );
$mock->clear()
	 ->set_series( 'sqlSelectMany', 0, $mock )
	 ->set_always( 'fetchrow_hashref', 'hash' )
	 ->set_true( 'finish' );

$result = sqlSelectHashref( $mock, 'foo', 'bar', 'baz', 'quux', 'qiix' );
($method, $args) = $mock->next_call();
is( $method, 'sqlSelectMany', 'sqlSelectHashref() should call sqlSelectMany()');
is( join('-', @$args), "$mock-foo-bar-baz-quux-qiix", '... passing all args' );
ok( ! $result, '... returning false if that fails' );
is( sqlSelectHashref( $mock ), 'hash', '... or a fetched hashref on success' );
is( $mock->next_call( 3 ), 'finish', '... finishing the statement handle' );

can_ok( $package, 'sqlUpdate' );
$mock->clear()
	 ->mock( _quoteData => sub { [ 'n', 'm', 's' ], [ '?', 1, 8 ], [ 'foo' ] } )
	 ->set_always( 'genTableName', 'gentable' )
	 ->set_always( 'sqlExecute', 'executed' );

ok( ! sqlUpdate( $mock, 'table', {} ),
	'sqlUpdate() should return false without update data' );

my $data = { foo => 'bar' };
$result = sqlUpdate( $mock, 'table', $data );
($method, $args) = $mock->next_call();
is( $method, '_quoteData', '... quoting data, if present' );
is( $args->[1], $data, '... passing in the data argument' );
($method, $args) = $mock->next_call();
is( $method, 'genTableName', '... quoting the table name' );
is( $args->[1], 'table', '... passing in the table argument' );
($method, $args) = $mock->next_call();
is( $method, 'sqlExecute', '... and should execute query' );
is( $args->[1], "UPDATE gentable SET n = ?,\nm = 1,\ns = 8",
	'... with names and values quoted appropriately' );
is_deeply( $args->[2], [ 'foo' ], '.. and bound args as appropriate' );

$mock->clear();
sqlUpdate( $mock, 'table', $data, 'where clause' );
($method, $args) = $mock->next_call(3);
like( $args->[1], qr/\nWHERE where clause\n/m,
	'... adding the where clause as necessary' );

can_ok( $package, 'sqlInsert' );

$data = { foo => 'bar' };
$result = sqlInsert( $mock, 'table', $data );
($method, $args) = $mock->next_call();
is( $method, '_quoteData', 'sqlInsert() should quote data, if present' );
is( $args->[1], $data, '... passing in the data argument' );
($method, $args) = $mock->next_call();
is( $method, 'genTableName', '... quoting the table name' );
is( $args->[1], 'table', '... passing in the table argument' );
($method, $args) = $mock->next_call();
is( $method, 'sqlExecute', '... and should execute query' );
is( $args->[1], "INSERT INTO gentable (n, m, s) VALUES(?, 1, 8)",
	'... with names and values quoted appropriately' );
is_deeply( $args->[2], [ 'foo' ], '.. and bound args as appropriate' );

can_ok( $package, '_quoteData' );
my ($names, $values, $bound) =
	_quoteData( 'fake', { foo => 'bar', -baz => 'quux' } );
is( join('|', sort @$names), 'baz|foo',
	'_quoteData() should remove leading minus from names' );
ok( (grep { /quux/ } @$values), '... treating unquoted values literally' );
ok( (grep { /\?/, } @$values), '... and using placeholders for quoted ones' );
is( join('|', @$bound), 'bar', '... returning quoted values in bound arg' );

can_ok( $package, 'sqlExecute' );
{
	my $log;

	local *Everything::printLog;
	*Everything::printLog = sub { $log = shift };

	$mock->clear()
		 ->set_series( 'prepare', $mock, 0 )
		 ->set_always( 'execute', 'success' );

	$result = sqlExecute( $mock, 'sql here', [ 1, 2, 3 ] );
	($method, $args) = $mock->next_call();
	is( $method, 'prepare', 'sqlExecute() should prepare a statement' );
	is( $args->[1], 'sql here', '... with the passed in SQL' );

	($method, $args) = $mock->next_call();
	is( $method, 'execute', '... executing the statement' );
	is( join('-', @$args), "$mock-1-2-3", '... with bound variables' );
	is( $result, 'success', '... returning the results' );

	ok( ! sqlExecute( $mock, 'bad', [ 6, 5, 4 ] ), '... or false on failure' );
	is( $log, "SQL failed: bad [6 5 4]\n", '... logging SQL and bound values' );
}
