#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use Test::More tests => 79;
use Test::Exception;
use Test::MockObject;

# temporarily avoid sub redefined warnings
my $mock = Test::MockObject->new();
$mock->fake_module('Everything');
$mock->fake_module('DBI');

my $package = 'Everything::NodeBase::mysql';

use_ok($package);

can_ok( $package, 'databaseConnect' );
my $fake = {};
my @args = ( 0, 'new dbh' );
my @dconn;
$mock->fake_module( 'DBI', connect => sub { push @dconn, [@_]; shift @args } );
throws_ok { Everything::NodeBase::mysql::databaseConnect( $fake, 1, 2, 3, 4 ) }
	qr/^Unable to get database connection!/,
	'databaseConnect() should fail if db connection fails';
lives_ok { Everything::NodeBase::mysql::databaseConnect( $fake, 1, 2, 3, 4 ) }
	'... but not if connection succeeds';
is( @dconn, 2, '... calling DBI->connect' );
is(
	join( '-', @{ $dconn[1] } ),
	'DBI-DBI:mysql:1:2-3-4',
	'... passing args correctly'
);
is( $fake->{dbh}, 'new dbh', '... setting dbh field if connection succeeds' );

can_ok( $package, 'lastValue' );
$mock->set_always( 'sqlSelect', 'insert id' );
my $result = Everything::NodeBase::mysql::lastValue($mock);
my ( $method, $args ) = $mock->next_call();
is( $method, 'sqlSelect', 'lastValue() should fetch from the database' );
is( $args->[1], 'LAST_INSERT_ID()', '... the last inserted id' );
is( $result, 'insert id', '... returning the results' );

my $fields = [ { Field => 'foo', foo => 1 }, { Field => 'bar', bar => 2 } ];

can_ok( $package, 'getFieldsHash' );
$mock->{dbh} = $mock;
$mock->set_always( 'getNode', $mock )->set_always( 'prepare_cached', $mock )
	->set_true('execute')->set_series( 'fetchrow_hashref', @$fields );

my @result = Everything::NodeBase::mysql::getFieldsHash( $mock, 'table' );
( $method, $args ) = $mock->next_call();
is( $method, 'getNode', 'getFieldsHash() should fetch node' );
is( join( '-', @$args[ 1, 2 ] ),
	'table-dbtable', '... by name, of dbtable type' );
( $method, $args ) = $mock->next_call();
is( $method, 'prepare_cached', '... displaying the table columns' );
is( $args->[1], 'show columns from table', '... for the appropriate table' );
is_deeply( $mock->{Fields}, $fields, '... caching the results' );
is_deeply( \@result, $fields, '... defaulting to return complete hashrefs' );

$mock->clear();
@result = Everything::NodeBase::mysql::getFieldsHash( $mock, '', 0 );
is( $mock->call_pos(-1), 'getNode',
	'getFieldsHash() should respect fields cached in node' );
( $method, $args ) = $mock->next_call();
is( $args->[1], 'node', '... using the node table by default' );
is_deeply(
	\@result,
	[ 'foo', 'bar' ],
	'... returning only fields if getHash is false'
);

can_ok( $package, 'tableExists' );
$mock->set_always( prepare => $mock )->set_true('execute')
	->set_series( 'fetchrow', 1, 2, 'target' )->set_true('finish');

$result = Everything::NodeBase::mysql::tableExists( $mock, 'target' );
( $method, $args ) = $mock->next_call();
is( $method, 'prepare', 'tableExists should check with the database' );
is( $args->[1], 'show tables', '... fetching available table names' );
ok( $result, '... returning true if table exists' );
is( $mock->call_pos(-1), 'finish', '... and closing the cursor' );

$mock->mock( 'fetchrow', sub { } );
ok(
	!Everything::NodeBase::mysql::tableExists( $mock, 'target' ),
	'... returning false if table name is not found'
);

can_ok( $package, 'createNodeTable' );
$mock->clear();
$mock->set_series( 'tableExists', 1, 0 )->set_always( 'do', 'done' );

$result = Everything::NodeBase::mysql::createNodeTable( $mock, 'elbat' );
( $method, $args ) = $mock->next_call();
is( $method, 'tableExists', 'createNodeTable() should check if table exists' );
is( $args->[1], 'elbat', '... by name' );
is( $result, -1, '... returning -1 if so' );

$result = Everything::NodeBase::mysql::createNodeTable( $mock, 'elbat' );
( $method, $args ) = $mock->next_call(2);
is( $method, 'do', '... performing a SQL create otherwise' );
like( $args->[1], qr/create table elbat/, '.. of the right name' );
like( $args->[1], qr/\(elbat_id int4/,    '... with an id column' );
like( $args->[1], qr/.+KEY\(elbat_id\)/,  '... as the primary key' );
is( $result, 'done', '... returning the results' );

can_ok( $package, 'createGroupTable' );
$mock->clear();
$mock->set_series( 'tableExists', 1, 0 )->set_always( 'do', 'done' )
	->set_always( 'getDatabaseHandle', $mock );

$result = Everything::NodeBase::mysql::createGroupTable( $mock, 'elbat' );
( $method, $args ) = $mock->next_call();
is( $method, 'tableExists', 'createGroupTable() should check if table exists' );
is( $args->[1], 'elbat', '... by name' );
is( $result, -1, '... returning -1 if so' );

$result = Everything::NodeBase::mysql::createGroupTable( $mock, 'elbat' );
( $method, $args ) = $mock->next_call(3);
is( $method, 'do', '... performing a SQL create otherwise' );
like( $args->[1], qr/create table elbat/, '.. of the right name' );
like( $args->[1], qr/elbat_id int4/,      '... with an id column' );
like(
	$args->[1],
	qr/rank .+node_id .+orderby/s,
	'... rank, node_id, and orderby columns'
);
like( $args->[1], qr/.+KEY\(elbat_id,rank\)/, '... as the primary key' );
is( $result, 'done', '... returning the results' );

can_ok( $package, 'dropFieldFromTable' );
$mock->clear();
$result = Everything::NodeBase::mysql::dropFieldFromTable( $mock, 't', 'f' );
( $method, $args ) = $mock->next_call();
is( $method, 'do', 'dropFieldFromTable() should do a SQL statement' );
is(
	$args->[1],
	'alter table t drop f',
	'... altering the table, dropping the column'
);
is( $result, 'done', '... returning the results' );

can_ok( $package, 'addFieldToTable' );
ok(
	!Everything::NodeBase::mysql::addFieldToTable( $mock, '' ),
	'addFieldToTable() should return false if table is blank'
);
ok( !Everything::NodeBase::mysql::addFieldToTable( $mock, 't', '' ),
	'... or if fieldname is blank' );
ok( !Everything::NodeBase::mysql::addFieldToTable( $mock, 't', 'f', '' ),
	'... or if type is blank' );

$mock->clear();
Everything::NodeBase::mysql::addFieldToTable( $mock, 't', 'f', 'text', 0 );
( $method, $args ) = $mock->next_call();
is( $method, 'do', 'addFieldToTable() should execute SQL statement' );
like(
	$args->[1],
	qr/^alter table t add f text/,
	'... altering proper table to add proper field and type'
);
like(
	$args->[1],
	qr/default "" not null/,
	'... with a blank default for text fields'
);
Everything::NodeBase::mysql::addFieldToTable( $mock, 't', 'f', 'int', 0 );
( $method, $args ) = $mock->next_call();
like(
	$args->[1],
	qr/default "0" not null/,
	'... a zero default for int fields'
);
Everything::NodeBase::mysql::addFieldToTable( $mock, 't', 'f', 'something else',
	0 );
( $method, $args ) = $mock->next_call();
like(
	$args->[1],
	qr/default "" not null/,
	'... a blank default for all other fields'
);
Everything::NodeBase::mysql::addFieldToTable( $mock, 't', 'f', 'something else',
	0, 'default' );
( $method, $args ) = $mock->next_call();
like(
	$args->[1],
	qr/default "default" not null/,
	'... and the given default, if given'
);

$mock->mock( 'getFieldsHash', sub { } )->clear();
Everything::NodeBase::mysql::addFieldToTable( $mock, 't', 'f', 'something else',
	1, 'default' );
( $method, $args ) = $mock->next_call(2);
is( $method, 'getFieldsHash', '... getting node fields if adding primary key' );
is( $args->[1], 't', '... for table' );
( $method, $args ) = $mock->next_call();
is( $method, 'do', '... altering the table' );
is(
	$args->[1],
	'alter table t add primary key(f)',
	'... adding a key for the field'
);

$mock->mock(
	'getFieldsHash',
	sub {
		{ Field => 'foo', Key => 'PRI' }, { Field => 'bar', Key => '' },
			{ Field => 'baz', Key => 'PRI' };
	}
)->clear();
$result =
	Everything::NodeBase::mysql::addFieldToTable( $mock, 't', 'f',
	'something else',
	1, 'default' );
( $method, $args ) = $mock->next_call(3);
is( $method, 'do', '... dropping an existing primary key' );
is( $args->[1], 'alter table t drop primary key', '... if it exists' );
( $method, $args ) = $mock->next_call();
is(
	$args->[1],
	'alter table t add primary key(foo,baz,f)',
	'... adding existing fields and new field as primary key'
);
ok( $result, '... returning true' );

foreach my $meth (qw(startTransaction commitTransaction rollbackTransaction))
{
	can_ok( $package, $meth );
	ok( $package->$meth(), "$method() should return true" );
}

can_ok( $package, 'genLimitString' );
is( $package->genLimitString( 10, 20 ),
	'LIMIT 10, 20', 'genLimitString() should return a valid limit' );
is( $package->genLimitString( undef, 20 ),
	'LIMIT 0, 20', '... defaulting to an offset of zero' );

can_ok( $package, 'genTableName' );
is( $package->genTableName('foo'),
	'foo', 'genTableName() should return first arg' );
