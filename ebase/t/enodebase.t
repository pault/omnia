#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use strict;
use vars qw( $AUTOLOAD );

use Test::More tests => 38;
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

can_ok( $package, 'sqlDelete' );
$mock->{dbh} = $mock;
ok( ! sqlDelete(), 'sqlDelete() should return false with no where clause' );

$mock->set_always( 'genTableName', 'table name' )
	 ->set_always( 'prepare', $mock )
	 ->set_always( 'execute', 'executed' );

my $result = sqlDelete( $mock, 'table', 'clause', [ 'one', 'two' ]);
my ($method, $args) = $mock->next_call();
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
can_ok( $package, 'sqlInsert' );
