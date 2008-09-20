package Everything::DB::Test::sqlite;

use Test::More;
use Test::Exception;
use File::Temp;
use Scalar::Util qw/blessed/;
use SUPER;
use base 'Everything::Test::DB';
use strict;
use warnings;

## override superclass sub redefining as mysql.pm has its own.

sub redefine_subs {

    1;

}

# a useful set of lists
my @lists = ( [qw/one list/], [qw/two list/], [qw/three list/] );

sub fake_dbh {
    my $self = shift;
    $self->{instance}->{dbh} = Test::MockObject->new;
    $self->{instance}->{dbh}->mock( 'quote', sub { qq|'$_[1]'| } );
    $self->{instance}->{dbh}->set_always( 'prepare', $self->{instance}->{dbh} );
    $self->{instance}->{dbh}->set_always( 'execute', $self->{instance}->{dbh} );
    $self->{instance}->{dbh}->mock( 'fetchrow', sub { qw/a list/ } );
    $self->{instance}->{dbh}->mock( 'fetch',    sub { qw/a list/ } );
    {
        my @a = @lists;
        $self->{instance}->{dbh}->mock( 'fetchrow_array',
            sub { return unless my $b = shift @a; return @$b } );
    }
    $self->{instance}->{dbh}
      ->set_true( 'finish', 'do', 'commit', 'rollback', 'begin_work' );
    $self->{instance}->{dbh}
      ->set_always( 'fetchrow_hashref', { title => 'wow', bright => 'sky' } );
}

sub test_database_connect : Test(5) {
    my $self = shift;

    can_ok( $self->{class}, 'databaseConnect' ) || return;
    my $fake = {};
    my @args = ( 0, 'new dbh' );
    my @dconn;
    my $mock = Test::MockObject->new;
    $mock->fake_module( 'DBI',
        connect => sub { push @dconn, [@_]; shift @args } );

    throws_ok { $self->{instance}->databaseConnect( 1, 2, 3, 4 ) }
      qr/^Unable to get database connection!/,
      'databaseConnect() should fail if db connection fails';
    lives_ok { $self->{instance}->databaseConnect( 1, 2, 3, 4 ) }
      '... but not if connection succeeds';
    is( @dconn, 2, '... calling DBI->connect' );
    is(
        join( '-', @{ $dconn[1] } ),
        'DBI-dbi:SQLite:dbname=1-3-4',
        '... passing args correctly'
    );

    $self->fake_dbh();
}

sub test_get_fields_hash : Test(9) {
    my $self = shift;

    can_ok( $self->{class}, 'getFieldsHash' ) || return;
    $self->{instance}->{nb}->clear;
    $self->{instance}->{dbh}->clear;

    my @fields1 = qw/foo bar/;
    my @fields2 = qw/ saturn jupiter /;
    $self->{instance}->{dbh}->mock( 'prepare', sub { shift; } );
    $self->{instance}->{dbh}
      ->set_series( 'fetchrow_arrayref', \@fields1, \@fields2 );
    my $DBTABLE = {};
    my @expected = @{ $DBTABLE->{Fields} } =
      map { { Field => $_ } } qw/bar jupiter/;

    my @result = $self->{instance}->getFieldsHash('table');
    my ( $method, $args ) = $self->{instance}->{nb}->next_call();
    is( $method, 'getNode', 'getFieldsHash() should fetch node' );
    is( join( '-', @$args[ 1, 2 ] ),
        'table-dbtable', '... by name, of dbtable type' );
    ( $method, $args ) = $self->{instance}->{dbh}->next_call();

    is( $method, 'prepare', '... displaying the table columns' );
    is(
        $args->[1],
        'PRAGMA table_info(table)',
        '... for the appropriate table'
    );

    is_deeply( \@result, \@expected,
        '... defaulting to return complete hashrefs' );

    $self->{instance}->{nb}->clear();
    $self->{instance}->{dbh}->clear();

    ## reset this
    $self->{instance}->{dbh}
      ->set_series( 'fetchrow_arrayref', \@fields1, \@fields2 );

    @result = $self->{instance}->getFieldsHash( '', 0 );
    is( $self->{instance}->{nb}->call_pos(-1),
        'getNode', 'getFieldsHash() should respect fields cached in node' );
    ( $method, $args ) = $self->{instance}->{nb}->next_call();
    is( $args->[1], 'node', '... using the node table by default' );

    is_deeply( \@result, [qw/bar jupiter/],
        '... returning only fields if getHash is false' );

}

sub test_table_exists : Test(6) {
    my $self = shift;

    can_ok( $self->{class}, 'tableExists' );
    $self->{instance}->{dbh}->set_true( 'fetchrow_array')->clear;

    my $result = $self->{instance}->tableExists('target');
    my ( $method, $args ) = $self->{instance}->{dbh}->next_call();
    is( $method, 'prepare', 'tableExists should check with the database' );
    is(
        $args->[1],
        q|SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?|,
        '... fetching available table names'
    );


    ok( $result, '... returns true if it exists.' );

    is( $self->{instance}->{dbh}->call_pos(-1), 'fetchrow_array', '... calls fetches a list.' );

    $self->{instance}->{dbh}->set_false('fetchrow_array');
    ok(
        !$self->{instance}->tableExists('target'),
        '... returning false if table name is not found'
    );

}

sub test_last_value : Test(3) {
    my $self = shift;
    $self->{instance}->{dbh}->set_true('func');
    $self->{instance}->{dbh}->clear; 
    ok( $self->{instance}->lastValue );
    my ( $method, $args ) = $self->{instance}->{dbh}->next_call;
    is( $method, 'func', '...calls func on the database' );
    is( $args->[1], 'last_insert_rowid', '...passes function name.' );

}

sub test_create_node_table : Test(9) {
    my $self = shift;

    can_ok( $self->{class}, 'createNodeTable' ) || return;

    $self->{instance}->{dbh}->clear();

    ## set fetch so that tableExists returns the appropriate value
    $self->{instance}->{dbh}->set_true('fetchrow_array');

    my $result = $self->{instance}->createNodeTable('proserpina');
    my ( $method, $args ) = $self->{instance}->{dbh}->next_call();
    is( $method, 'prepare', 'createNodeTable() should check if table exists' );
    is(
        $args->[1],
        q|SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?|,
        '... creates some SQL.'
    );
    is( $result, -1, '... returning -1 if so' );

    $self->{instance}->{dbh}->clear();

    # for the benefit of tableExists
    $self->{instance}->{dbh}->set_false('fetchrow_array');
    $result = $self->{instance}->createNodeTable('euphrosyne');
    ( $method, $args ) = $self->{instance}->{dbh}->next_call;
    is( $method, 'prepare', '... calls tableExists' );
    ( $method, $args ) = $self->{instance}->{dbh}->next_call(3);

    is( $method, 'do', '... performing a SQL create otherwise' );
    like( $args->[1], qr/create table euphrosyne/, '.. of the right name' );
    like( $args->[1], qr/\(euphrosyne_id int4/,    '... with an id column' );
    is( $result, '1', '... returns success.' );

}

sub test_create_group_table : Test(8) {
    my $self = shift;

    can_ok( $self->{class}, 'createGroupTable' );
    $self->{instance}->{dbh}->clear();

    $self->{instance}->{dbh}->set_true('fetchrow_array');

    my $result = $self->{instance}->createGroupTable('proserpina');
    my ( $method, $args ) = $self->{instance}->{dbh}->next_call();
    is( $method, 'prepare', 'Attempt to amend an existing table' );
    is( $result, -1,        '... returning -1 if so' );

    $self->{instance}->{dbh}->set_false('fetchrow_array');
    $self->{instance}->{dbh}->clear();
    $result = $self->{instance}->createGroupTable('elbat');
    ( $method, $args ) = $self->{instance}->{dbh}->next_call(4);
    is( $method, 'do', '... performing a SQL create otherwise' );
    like( $args->[1], qr/create table elbat/, '.. of the right name' );
    like( $args->[1], qr/elbat_id int4/,      '... with an id column' );
    like(
        $args->[1],
        qr/rank .+node_id .+orderby/s,
        '... rank, node_id, and orderby columns'
    );
    is( $result, 1, '... returns success' );

}

sub test_drop_field_from_table : Test(2) {

    my $self = shift;

    can_ok( $self->{class}, 'dropFieldFromTable' );
    $self->{instance}->{dbh}->clear();

    dies_ok(
        sub {
            $self->{instance}->dropFieldFromTable( 't', 'f' );
        },
        "Drop field from table not yet implemented - requires recreating table."
    );

}

sub test_add_field_to_table : Test(13) {
    my $self = shift;
    $self->{instance}->{dbh}
      ->set_always( 'prepare_cached', $self->{instance}->{dbh} );
    my $fields = [
        { Field => 'foo', Key => 'PRI' },
        { Field => 'bar', Key => '' },
        { Field => 'baz', Key => 'PRI' }
    ];
    $self->{instance}->{dbh}->set_series( 'fetchrow_hashref', @$fields );

    $self->{instance}->{dbh}->clear();
    can_ok( $self->{class}, 'addFieldToTable' );
    ok( !$self->{instance}->addFieldToTable(''),
        'addFieldToTable() should return false if table is blank' );
    ok( !$self->{instance}->addFieldToTable( 't', '' ),
        '... or if fieldname is blank' );

    $self->{instance}->{dbh}->set_series( 'fetchrow_hashref', @$fields );
    ok( !$self->{instance}->addFieldToTable( 't', 'f', '' ),
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

    $self->{instance}->addFieldToTable( 't', 'f', 'int', 0 );
    ( $method, $args ) = $self->{instance}->{dbh}->next_call();
    like(
        $args->[1],
        qr/default "0" not null/,
        '... a zero default for int fields'
    );
    $self->{instance}->{dbh}->clear;
    $self->{instance}->addFieldToTable( 't', 'f', 'something else', 0 );
    ( $method, $args ) = $self->{instance}->{dbh}->next_call();
    like(
        $args->[1],
        qr/default "" not null/,
        '... a blank default for all other fields'
    );

    $self->{instance}->{dbh}->clear;
    $self->{instance}->{dbh}->set_series( 'fetchrow_hashref', @$fields );
    $self->{instance}
      ->addFieldToTable( 't', 'f', 'something else', 0, 'default' );
    ( $method, $args ) = $self->{instance}->{dbh}->next_call();
    like(
        $args->[1],
        qr/default "default" not null/,
        '... and the given default, if given'
    );

    $self->{instance}->{dbh}->clear();
    $self->{instance}
      ->addFieldToTable( 't', 'f', 'something else', 0, 'default' );
    ( $method, $args ) = $self->{instance}->{dbh}->next_call(1);
    is( $method, 'do', '... for table' );
    is(
        $args->[1],
        'alter table t add f something else default "default" not null',
        '... makes some sql to amend a table.'
    );


    #### if the new field is the primary key

    $self->{instance}->{dbh}->set_series( 'fetchrow_hashref', @$fields )->clear;

    dies_ok( sub {
      $self->{instance}
      ->addFieldToTable( 't', 'f', 'something else', 1, 'default' ) },
	   "Add primary keys not implemented - need to recreate table.");


}

sub test_start_transaction : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'startTransaction' );
    ok( $self->{instance}->startTransaction, '...should return true' );
    ## of course mysql supports transactions now for some table types
    ## so this should change to reflect that.

}

sub test_commit_transaction : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'commitTransaction' );
    ok( $self->{instance}->commitTransaction, '...should return true' );

}

sub test_rollback_transaction : Test(2) {
    my $self = shift;

    can_ok( $self->{class}, 'rollbackTransaction' );
    ok( $self->{instance}->rollbackTransaction, '...should return true' );

}

sub test_gen_limit_string : Test(3) {
    my $self = shift;

    can_ok( $self->{class}, 'genLimitString' );
    is( $self->{class}->genLimitString( 10, 20 ),
        'LIMIT 10, 20', 'genLimitString() should return a valid limit' );
    is( $self->{class}->genLimitString( undef, 20 ),
        'LIMIT 0, 20', '... defaulting to an offset of zero' );

}

sub test_gen_table_name : Test(2) {
    my $self = shift;

    can_ok( $self->{class}, 'genTableName' );
    is( $self->{class}->genTableName('foo'),
        'foo', 'genTableName() should return first arg' );
}

sub test_database_exists : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'databaseExists' ) || return;
    my $file = File::Temp->new;
    ok(
        $self->{instance}->databaseExists( "$file" ),
        '...returns true if it exists'
    );
    ok ( ! $self->{instance}->databaseExists( "$file" . "KKK"),
        '...and false if it does not.' );
}

sub test_list_tables : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'list_tables' ) || return;
    my @list     = (qw/auxo charis hegemone phaenna pasithea/);
    my @expected = @list;
    $self->{instance}->{dbh}->mock(
        'fetchrow',
        sub {
            my $r = shift @list;
            return () unless $r;
            return ($r);
        }
    );

    is_deeply( [ $self->{instance}->list_tables ],
        \@expected, '...returns all the tables in the DB.' );

}

sub test_drop_node_table : Test(+0) {
    my ($self) = @_;
    $self->{instance}->{dbh}->set_series( 'fetchrow_array', 0, 1 );
    $self->SUPER;

}

sub test_now : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'now' ) || return;
    is( $self->{instance}->now, "datetime('now')", '... calls sqlite datetime function.' );
}

sub test_timediff : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'timediff' ) || return;
    is( $self->{instance}->timediff( 2, 1 ),
        '2 - 1', '... makes a string from the arguments.' );
}

sub test_get_create_table : Test(6) {
    my $self = shift;

    my $dbh = $self->{instance}->{dbh};
    $dbh->clear;
    my @returns = map { [ $_ ] } qw/one two three/;
    $dbh->mock('fetchrow_arrayref' => sub { shift @returns });
    my @create = $self->{instance}->get_create_table('atable');

    my ($method, $args) = $self->{instance}->{dbh}->next_call;
    is ($method, 'prepare', '...prepares statement');
    is ($$args[1], "select sql from sqlite_master where type = 'table' and name = 'atable'", '...creates sql with one where');
    is_deeply (\@create, [ qw/one two three/ ], '...and returns a list');

    $dbh->clear;

    @create = $self->{instance}->get_create_table('atable', 'btable', 'ctable');
    ($method, $args) = $self->{instance}->{dbh}->next_call;
    is ($method, 'prepare', '...prepares statement');
    is ($$args[1], "select sql from sqlite_master where type = 'table' and name = 'atable' or name = 'btable' or name = 'ctable'", '...creates sql with three wheres');

   $dbh->clear;

    @create = $self->{instance}->get_create_table();
    ($method, $args) = $self->{instance}->{dbh}->next_call;
    is ($$args[1], "select sql from sqlite_master where type = 'table'", '...creates sql with no where');

}

1;
