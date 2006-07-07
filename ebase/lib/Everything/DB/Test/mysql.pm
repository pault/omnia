package Everything::DB::Test::mysql;

use Test::More;
use Test::Exception;
use Scalar::Util qw/blessed/;
use SUPER;
use base 'Everything::Test::DB';
use strict;
use warnings;

## override superclass sub redefining as mysql.pm has its own.

sub redefine_subs {

  1;

}


sub test_drop_node_table :Test(+0) {
  my $self = shift;

  ## This depends on the order of tests in the superclass method. If
  ## that changes this will break.
  my @list = (undef, qw/proserpina ceres/);
  $self->{instance}->{dbh}->mock( 'fetchrow',
				  sub {
				    my $r = shift @list;
				    return () unless $r;
				    return ($r)
				  }
				);

  $self->SUPER();
}

sub test_database_connect : Test(5)
{
     my $self = shift;

     can_ok( $self->{class}, 'databaseConnect') || return;
     my $fake = {};
     my @args = ( 0, 'new dbh' );
     my @dconn;
     my $mock = Test::MockObject->new;
     $mock->fake_module( 'DBI', connect => sub { push @dconn, [@_]; shift @args } );
     throws_ok { Everything::DB::mysql::databaseConnect( $fake, 1, 2, 3, 4 ) }
  qr/^Unable to get database connection!/,
  'databaseConnect() should fail if db connection fails';
     lives_ok { Everything::DB::mysql::databaseConnect( $fake, 1, 2, 3, 4 ) }
  '... but not if connection succeeds';
     is( @dconn, 2, '... calling DBI->connect' );
     is(
	join( '-', @{ $dconn[1] } ),
	'DBI-DBI:mysql:1:2-3-4',
	'... passing args correctly'
);


}

sub test_get_fields_hash : Test(9)
{
  my $self = shift;

  can_ok( $self->{class}, 'getFieldsHash' ) || return;
  $self->{instance}->{nb}->clear;
  $self->{instance}->{dbh}->clear;
  my $fields = [ { Field => 'foo', foo => 1 }, { Field => 'bar', bar => 2 } ];
  $self->{instance}->{dbh}->mock( 'prepare_cached', sub {shift;} );
  $self->{instance}->{dbh}->set_series( 'fetchrow_hashref', @$fields );

  my @result = $self->{instance}->getFieldsHash( 'table' );
  my ( $method, $args ) = $self->{instance}->{nb}->next_call();
  is( $method, 'getNode', 'getFieldsHash() should fetch node' );
  is( join( '-', @$args[ 1, 2 ] ),
      'table-dbtable', '... by name, of dbtable type' );
  ( $method, $args ) = $self->{instance}->{dbh}->next_call();

  is( $method, 'prepare_cached', '... displaying the table columns' );
  is( $args->[1], 'show columns from table', '... for the appropriate table' );

  is_deeply( \@result, $fields, '... defaulting to return complete hashrefs' );

  $self->{instance}->{nb}->clear();
  $self->{instance}->{dbh}->clear();
  $self->{instance}->{dbh}->set_series( 'fetchrow_hashref', @$fields );
  @result = $self->{instance}->getFieldsHash('', 0 );
  is( $self->{instance}->{nb}->call_pos(-1), 'getNode',
      'getFieldsHash() should respect fields cached in node' );
  ( $method, $args ) = $self->{instance}->{nb}->next_call();
  is( $args->[1], 'node', '... using the node table by default' );
  is_deeply(
	    \@result,
	    [ 'foo', 'bar' ],
	    '... returning only fields if getHash is false'
	   );


}

sub test_table_exists : Test(6)
{
     my $self = shift;

can_ok( $self->{class}, 'tableExists' );
     $self->{instance}->{dbh}
	->set_series( 'fetchrow', 1, 2, 'target' );

     my $result = $self->{instance}->tableExists('target' );
my ( $method, $args ) = $self->{instance}->{dbh}->next_call();
is( $method, 'prepare', 'tableExists should check with the database' );
is( $args->[1], 'show tables', '... fetching available table names' );
ok( $result, '... returning true if table exists' );
is( $self->{instance}->{dbh}->call_pos(-1), 'finish', '... and closing the cursor' );

$self->{instance}->{dbh}->mock( 'fetchrow', sub { } );
ok(
	!$self->{instance}->tableExists('target' ),
	'... returning false if table name is not found'
);


}

sub test_create_node_table : Test(10)
{
      my $self = shift;

can_ok( $self->{class}, 'createNodeTable' ) || return;

$self->{instance}->{dbh}->clear();



  my @list = (qw/proserpina ceres/);
  $self->{instance}->{dbh}->mock( 'fetchrow',
				  sub {
				    my $r = shift @list;
				    return () unless $r;
				    return ($r)
				  }
				);


my $result = $self->{instance}->createNodeTable('proserpina' );
my ( $method, $args ) = $self->{instance}->{dbh}->next_call();
is( $method, 'prepare', 'createNodeTable() should check if table exists' );
is( $args->[1], 'show tables', '... creates some SQL.' );
is( $result, -1, '... returning -1 if so' );
$self->{instance}->{dbh}->clear();
$result = $self->{instance}->createNodeTable('euphrosyne' );
( $method, $args ) = $self->{instance}->{dbh}->next_call;
is( $method, 'prepare', '... calls tableExists' );
( $method, $args ) = $self->{instance}->{dbh}->next_call(4);

is( $method, 'do', '... performing a SQL create otherwise' );
like( $args->[1], qr/create table euphrosyne/, '.. of the right name' );
like( $args->[1], qr/\(euphrosyne_id int4/,    '... with an id column' );
like( $args->[1], qr/.+KEY\(euphrosyne_id\)/,  '... as the primary key' );
is( $result, '1', '... returns success.' );


}

sub test_create_group_table : Test(8)
{
     my $self = shift;

can_ok( $self->{class}, 'createGroupTable' );
$self->{instance}->{dbh}->clear();

  my @list = (qw/proserpina ceres/);
  $self->{instance}->{dbh}->mock( 'fetchrow',
				  sub {
				    my $r = shift @list;
				    return () unless $r;
				    return ($r)
				  }
				);


my $result = $self->{instance}->createGroupTable( 'proserpina' );
my ( $method, $args ) = $self->{instance}->{dbh}->next_call();

is( $result, -1, '... returning -1 if so' );

$self->{instance}->{dbh}->clear();
$result = $self->{instance}->createGroupTable('elbat' );
( $method, $args ) = $self->{instance}->{dbh}->next_call(5);
is( $method, 'do', '... performing a SQL create otherwise' );
like( $args->[1], qr/create table elbat/, '.. of the right name' );
like( $args->[1], qr/elbat_id int4/,      '... with an id column' );
like(
	$args->[1],
	qr/rank .+node_id .+orderby/s,
	'... rank, node_id, and orderby columns'
);
like( $args->[1], qr/.+KEY\(elbat_id,rank\)/, '... as the primary key' );
is( $result, 1, '... returns success' );


}

sub test_drop_field_from_table : Test(4)
{
     my $self = shift;

can_ok( $self->{class}, 'dropFieldFromTable' );
$self->{instance}->{dbh}->clear();
my $result = $self->{instance}->dropFieldFromTable( 't', 'f' );
my ( $method, $args ) = $self->{instance}->{dbh}->next_call();
is( $method, 'do', 'dropFieldFromTable() should do a SQL statement' );
is(
	$args->[1],
	'alter table t drop f',
	'... altering the table, dropping the column'
);
is( $result, 1, '... returns success.' );


}

sub test_add_field_to_table : Test(16)
{
     my $self = shift;
$self->{instance}->{dbh}->set_always('prepare_cached', $self->{instance}->{dbh});
     my $fields = [ { Field => 'foo', Key => 'PRI' }, { Field => 'bar', Key => '' }, { Field => 'baz', Key => 'PRI' }];
  $self->{instance}->{dbh}->set_series( 'fetchrow_hashref', @$fields );

$self->{instance}->{dbh}->clear();
can_ok( $self->{class}, 'addFieldToTable' );
ok(
	!$self->{instance}->addFieldToTable( '' ),
	'addFieldToTable() should return false if table is blank'
);
ok( !$self->{instance}->addFieldToTable('t', '' ),
	'... or if fieldname is blank' );

  $self->{instance}->{dbh}->set_series( 'fetchrow_hashref', @$fields );
ok( !$self->{instance}->addFieldToTable('t', 'f', '' ),
	'... or if type is blank' );

$self->{instance}->{dbh}->clear();
$self->{instance}->addFieldToTable( 't', 'f', 'text', 0 );
my ( $method, $args ) = $self->{instance}->{dbh}->next_call();
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
$self->{instance}->addFieldToTable( $self->{instance}->{dbh}, 't', 'f', 'int', 0 );
( $method, $args ) = $self->{instance}->{dbh}->next_call();
like(
	$args->[1],
	qr/default "0" not null/,
	'... a zero default for int fields'
);
$self->{instance}->{dbh}->clear;
$self->{instance}->addFieldToTable('t', 'f', 'something else',
	0 );
( $method, $args ) = $self->{instance}->{dbh}->next_call();
like(
	$args->[1],
	qr/default "" not null/,
	'... a blank default for all other fields'
);

$self->{instance}->{dbh}->clear;
  $self->{instance}->{dbh}->set_series( 'fetchrow_hashref', @$fields );
$self->{instance}->addFieldToTable('t', 'f', 'something else',
	0, 'default' );
( $method, $args ) = $self->{instance}->{dbh}->next_call();
like(
	$args->[1],
	qr/default "default" not null/,
	'... and the given default, if given'
);

$self->{instance}->{dbh}->clear();
$self->{instance}->addFieldToTable(  't', 'f', 'something else',
	1, 'default' );
( $method, $args ) = $self->{instance}->{dbh}->next_call(1);
is( $method, 'do', '... for table' );
is(
	$args->[1],
	'alter table t add f something else default "default" not null',
	'... makes some sql to amend a table.'
);


#### if the new field is the primary key

  $self->{instance}->{dbh}->set_series( 'fetchrow_hashref', @$fields )
                          ->clear;

my $result =
	$self->{instance}->addFieldToTable( 't', 'f',
	'something else',
	1, 'default' );
( $method, $args ) = $self->{instance}->{dbh}->next_call(8);
is( $method, 'do', '... dropping an existing primary key' );
is( $args->[1], 'alter table t drop primary key', '... if it exists' );
( $method, $args ) = $self->{instance}->{dbh}->next_call();
is(
	$args->[1],
	'alter table t add primary key(foo,baz,f)',
	'... adding existing fields and new field as primary key'
);
ok( $result, '... returning true' );

}

sub test_start_transaction : Test(2)
{
     my $self = shift;
     can_ok( $self->{class}, 'startTransaction' );
     ok( $self->{instance}->startTransaction, '...should return true' );
     ## of course mysql supports transactions now for some table types
     ## so this should change to reflect that.

}

sub test_commit_transaction : Test(2)
{
     my $self = shift;
     can_ok( $self->{class}, 'commitTransaction' );
     ok( $self->{instance}->commitTransaction, '...should return true' );
 

}

sub test_rollback_transaction : Test(2)
{
     my $self = shift;
    can_ok( $self->{class}, 'rollbackTransaction' );
     ok( $self->{instance}->rollbackTransaction, '...should return true' );
 

}

 sub test_gen_limit_string : Test(3)
{
     my $self = shift;

     can_ok( $self->{class}, 'genLimitString' );
is( $self->{class}->genLimitString( 10, 20 ),
	'LIMIT 10, 20', 'genLimitString() should return a valid limit' );
is( $self->{class}->genLimitString( undef, 20 ),
	'LIMIT 0, 20', '... defaulting to an offset of zero' );


}

sub test_gen_table_name : Test(2)
{
     my $self = shift;

     can_ok( $self->{class}, 'genTableName' );
     is( $self->{class}->genTableName('foo'),
	'foo', 'genTableName() should return first arg' );
}




sub test_database_exists : Test(3)
{
     my $self = shift;
     can_ok($self->{class}, 'databaseExists') || return;
     my @list = (qw/algaea thalia/);
     $self->{instance}->{dbh}->mock( 'fetchrow',
				     sub {
				       my $r = shift @list;
				       return () unless $r;
				       return ($r)
				     }
				   );

     is($self->{instance}->databaseExists('algaea'), 1, '...returns true if database exists.');
     is($self->{instance}->databaseExists('herakles'), 0, '...returns database if database does not exist.');

}

sub test_list_tables : Test(2)
{
     my $self = shift;
     can_ok($self->{class}, 'list_tables') || return;
     my @list = (qw/auxo charis hegemone phaenna pasithea/);
     my @expected = @list;
     $self->{instance}->{dbh}->mock( 'fetchrow',
				     sub {
				       my $r = shift @list;
				       return () unless $r;
				       return ($r)
				     }
				   );

     is_deeply([$self->{instance}->list_tables], \@expected, '...returns all the tables in the DB.');



}

sub test_now : Test(2)
{
     my $self = shift;
     can_ok($self->{class}, 'now') || return;
     is($self->{instance}->now, 'now()', '... should return the DB function that returns current time/date');
}

sub test_timediff : Test(2)
{
     my $self = shift;
     can_ok($self->{class}, 'timediff') || return;
     is($self->{instance}->timediff(2, 1), '2 - 1', '... makes a string from the arguments.');
}

1;
