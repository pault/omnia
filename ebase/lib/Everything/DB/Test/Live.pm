package Everything::DB::Test::Live;

use base 'Test::Class';
use Everything::Config;
use Test::More;
use Test::Warn;
use Test::Exception;
use Carp;
use strict;
use warnings;
use SUPER;

# NB: genWhereString is not tested because it is sufficiently tested
# in other tests.

# lastValue - this behaves oddly and depends on the database.  We test
# it after every insert so we get the value we are expecting.

# Test class method doesn't quite do what we want
sub SKIP_CLASS {
    my $self = shift;
    my $class = ref $self ? ref $self : $self;
    $class->SUPER( @_ );


}

sub test_startup_1_create_database : Test(startup => 2) {

    my $self = shift;

    my $config = $self->{config};

    my $storage_class = 'Everything::DB::' . $config->database_type;

    ( my $file = $storage_class ) =~ s/::/\//g;
    $file .= '.pm';
    require $file;

    my $storage = $storage_class->new();

    $storage->create_database(
        $config->database_name,          $config->database_superuser,
        $config->database_superpassword, $config->database_host,
        $config->database_port
    );

    ok( !DBI->err, '...creates a database.' ) || diag DBI->err;

    $storage->grant_privileges( $config->database_name, $config->database_user,
        $config->database_password );

    ok( !DBI->err, '...grants privileges to user.' ) || diag DBI->err;

    $self->{super_storage} = $storage;

}

sub test_startup_2_install_base : Test(startup => 2 ) {

    my $self = shift;

    my $storage = $self->{super_storage};

    ok( defined $storage->install_base_tables, '...installs base tables.' );

    ok( defined $storage->install_base_nodes, '...installs base nodes.' );

}

sub test_startup_3_initialise_nodebase : Test(startup => 6) {

    my $self = shift;

    ok(
        my $nb = $self->{config}->nodebase,
        '...nodebase is called against config.'
    );
    isa_ok( $nb, 'Everything::NodeBase', '... nodebase object is valid.' );

    is( my @nodes = @{ $nb->getNodeWhere() },
        3, '... nodebase contains three nodes.' );

    is( $nodes[0]->get_title . $nodes[0]->get_type_nodetype,
        'nodetype1', '...the first node is a nodetype type.' );

    is( $nodes[1]->get_title . $nodes[1]->get_type_nodetype,
        'node1', '...the second node is a node type.' );

    is( $nodes[2]->get_title . $nodes[2]->get_type_nodetype,
        'setting1', '...the third node is a setting type.' );
    $self->{nodebase} = $nb;

    $self->{storage} = $nb->{storage};
}

sub test_delete_test_database : Test(shutdown => 1) {
    my $self = shift;
    ok(
        $self->{storage}->drop_database(
            $self->{config}->database_name,
            $self->{config}->database_superuser,
            $self->{config}->database_superpassword
        ),
        '... deletes the test database.'
    );

}

sub test_fetchall_nodetype_names : Test( 1 ) {

    my $self      = shift;
    my @nodetypes = $self->{storage}->fetch_all_nodetype_names;

    is( "@nodetypes", 'nodetype node setting', '...retrieves nodetype names.' );

}

sub test_get_database_handle : Test(1) {

    my $self = shift;
    isa_ok( $self->{storage}->getDatabaseHandle,
        'DBI::db', '...returns the DBI.pm object.' );
}

sub test_sql_select_joined : Test(4) {

    my $self = shift;
    my $s = $self->{ storage };
    ok ( my $sth = $s->sqlSelectJoined( 'title', 'node', { nodetype => 'node.node_id = nodetype.nodetype_id' }, undef, undef ) );

    my %results;
    while ( my $title = $sth->fetchrow_arrayref ) {
	$results{ $$title[0] } = 1;
    }
    is_deeply( \%results, { map { $_ => 1} qw/nodetype node setting/} , '...gets all nodetypes');

    # try bound variables
        ok ( $sth = $s->sqlSelectJoined( 'title', 'node', { nodetype => 'nodetype.nodetype_id = node.node_id' }, 'type_nodetype = ?', undef, [ 1 ] ) );


    while ( my $title = $sth->fetchrow_arrayref ) {
	$results{ $$title[0] } = 1;
    }
    is_deeply( \%results, { map { $_ => 1} qw/nodetype node setting/} , '...gets all nodetypes');

}

sub test_sql_select_many : Test(2) {

    my $self = shift;
    my $s = $self->{ storage };
    ok ( my $sth = $s->sqlSelectMany( 'title', 'node', 'type_nodetype = ? ', ' order by node_id ', [1] ) );


    my @results;
    while ( my $title = $sth->fetchrow_arrayref ) {
	push @results, @$title;
    }
    is_deeply( \@results, [ qw/nodetype node setting/ ] , '...gets nodetypes inorder.');

}

sub test_sql_select_hashref :Test(2) {

    my $self = shift;
    my $s = $self->{ storage };

    ok ( my $hash = $s->sqlSelectHashref( 'title, node_id', 'node', 'title = ? ', undef, [qw/setting/]), '...gets a hash.' );

    is_deeply( $hash, { title => 'setting', node_id => '3' }, '...which is properly constructed.');
}

sub test_sql_select : Test(3) {

    my $self = shift;
    my $s = $self->{ storage };

    ok( my $rv = $s->sqlSelect( 'node_id', 'node', " node_id = 3 " ), '...runs ok.');

    is ($rv,  3 , '..returns the value if only one value.' );

    $rv = $s->sqlSelect( 'node_id, title', 'node', " node_id = 3 " );

    is_deeply ($rv, [ 3, 'setting' ] , '..returns an array ref of array refs.' );

}

sub test_sql_insert_update_delete :Test(4) {

    my $self = shift;
    my $s = $self->{ storage };
    is( $s->sqlInsert( 'node', { title => 'testtitle', -createtime => $s->now } ), 1, '...insert one row.' );

    is( $s->lastValue( 'node', 'node_id' ), 4, '...lastValue is valid.');

    is( $s->sqlUpdate( 'node', { title => 'testtitle1' }, ' node_id = 4 ' ), 1, '...updates one row.');

    is( $s->sqlDelete( 'node', ' title = ? ', [ 'testtitle1' ] ), 1, '...deletes one row.' ) || diag $DBI::errstr;
}

sub test_sql_execute :Test(1) {

    my $self = shift;
    my $s = $self->{ storage };

    ## return value depends on database, may be 1 may be 0E0.
   ok ( my $rv = $s->sqlExecute( 'select * from node where node_id = ?', [1] ), '..returns on success.' ) || diag $DBI::errstr;
}

my @nodes = (
	     { title => 'nodetype',
	       type_nodetype => 1,
#	       modified => undef,
	       authoraccess => 'iiii',
	       groupaccess => 'rwxdc',
	       otheraccess => '-----',
	       guestaccess => '-----',
	       dynamicauthor_permission => 0,
	       dynamicgroup_permission => 0,
	       dynamicother_permission => 0,
	       dynamicguest_permission => 0,
	       group_usergroup => 0,
	       restrict_nodetype => 0,
	       extends_nodetype => 2,
	       restrictdupes => 1,
	       sqltable => 'nodetype',
	       grouptable => '',
	       defaultauthoraccess => 'rwxd',
	       defaultgroupaccess => 'rwxdc',
	       defaultotheraccess => '-----',
	       defaultguestaccess => '-----',
	       defaultgroup_usergroup => 0,
	       defaultauthor_permission => 0,
	       defaultgroup_permission => 0,
	       defaultother_permission => 0,
	       defaultguest_permission => 0,
	       canworkspace => 0
	     },
	     { title => 'node',
	       type_nodetype => 1,
#	       modified => undef, temporarily disabled
	       authoraccess => 'rwxd',
	       groupaccess => '-----',
	       otheraccess => '-----',
	       guestaccess => '-----',
	       group_usergroup => 0,
	       restrict_nodetype => 0,
	       extends_nodetype => 0,
	       restrictdupes => 1,
	       sqltable => '',
	       grouptable => '',
	       defaultauthoraccess => 'rwxd',
	       defaultgroupaccess => 'r----',
	       defaultotheraccess => '-----',
	       defaultguestaccess => '-----',
	       defaultgroup_usergroup => 0,
	       defaultauthor_permission => 0,
	       defaultgroup_permission => 0,
	       defaultother_permission => 0,
	       defaultguest_permission => 0,
	       maxrevisions => 1000,
	       canworkspace => 1
	     },
	     { title => 'setting',
	       type_nodetype => 1,
#	       modified => undef, temporarily disabled
	       authoraccess => 'rwxd',
	       groupaccess => '-----',
	       otheraccess => '-----',
	       guestaccess => '-----',
	       dynamicauthor_permission => 0,
	       dynamicgroup_permission => 0,
	       dynamicother_permission => 0,
	       dynamicguest_permission => 0,
	       group_usergroup => 0,
	       restrict_nodetype => 0,
	       extends_nodetype => 2,
	       restrictdupes => 1,
	       sqltable => 'setting',
	       grouptable => '',
	       defaultauthoraccess => 'rwxd',
	       defaultgroupaccess => '-----',
	       defaultotheraccess => '-----',
	       defaultguestaccess => '-----',
	       defaultgroup_usergroup => 0,
	       defaultauthor_permission => 0,
	       defaultgroup_permission => 0,
	       defaultother_permission => 0,
	       defaultguest_permission => 0,
	     }
);

sub test_get_node_by_id_new :Test(6) {

    my $self = shift;
    my $s = $self->{ storage };

    my %nodes = ( 1 => 'nodetype', 2 => 'node', 3 => 'setting' );

    foreach ( keys %nodes ) {
	is( $s->getNodeByIdNew( $_ )->{ title }, $nodes{ $_ }, '..retrieves installed node.' );
    }

    for ( 1.. 3 ) {
	my $n =  $s->getNodeByIdNew( $_ );
        my $m = $nodes[ $_-1 ];
	my %o = map { $_ => $n->{ $_ }  } keys %$m;
	is_deeply ( \%o, $m, '...node is properly constructed.' );
    }
}

sub test_get_node_by_name :Test(2) {

    my $self = shift;
    my $s = $self->{ storage };

    my $type = $self->{ nodebase }->getType( 'nodetype' );
    isa_ok( my $node = $s->getNodeByName( 'setting', $type ), 'HASH', '...returns hash ref.');
    is ( $node->{ title } . $node->{ type_nodetype }, 'setting1', '..of the correct title and type.');
}

sub test_select_node_where :Test(3) {

    my $self = shift;
    my $s = $self->{ storage };

    is_deeply( $s->selectNodeWhere, [1,2,3], '...gets ids of all nodes.');

    my $totalrows;
    $s->selectNodeWhere( undef, undef, undef, undef, undef, \$totalrows);

    is ( $totalrows, 3, '...reports total rows.' );

    is_deeply( $s->selectNodeWhere( undef, undef, 'node_id', 1, 1 ), [2], '...gets nodes if offset used.');
}

sub test_count_node_matches :Test(2) {

    my $self = shift;
    is( $self->{ storage }->countNodeMatches, 3, '...count all nodes.');
    is( $self->{ storage }->countNodeMatches( { title => 'setting' }, 'nodetype'), 1, '...count by nodetype.');

}


sub test_get_all_types :Test(2) {

    my $self = shift;

    is( my @types = $self->{ storage }->getAllTypes, 3, '..returns all types.' );
    is( join( ' ', sort map { $_->get_title } @types), 'node nodetype setting', '...returns only type nodes.');

}


sub test_get_nodetype_tables :Test(2) {

    my $self = shift;
    my $s = $self->{ storage };
    my $type = $self->{ nodebase }->getType( 'setting' );
    is_deeply ( $s->getNodetypeTables( $type ), [ qw/setting/ ], '...fetches table names. ' );
    is_deeply ( $s->getNodetypeTables( $type, 1 ), [ qw/setting node/ ], '... and adds node if ask to do so. ' );

}

sub test_get_node_cursor :Test(3) {

    my $self = shift;
    my $s = $self->{ storage };

    my @errs;
    local *Everything::logErrors;
    *Everything::logErrors = sub { @errs = @_ };

    isa_ok( my $rv = $s->getNodeCursor ('title', undef, undef, 'node_id'), 'DBI::st', '...returns a statement handle.') || diag "@errs";

    my $results = $rv->fetchall_arrayref;

    is_deeply ( $results, [ map { [ $_ ] } qw/nodetype node setting/], '...which executes.' );

    ## run again with offset 
    $rv = $s->getNodeCursor ('title', undef, undef, 'node_id', 1, 1);

    $results = $rv->fetchall_arrayref;

    is_deeply ( $results, [ map { [ $_ ] } qw/node/], '...offset works.' );

}

sub test_timediff :Test(1) {


}


sub test_nodetable1_create_node_table :Test(3) {

    my $self = shift;
    my $s = $self->{ storage };
    is ($s->createNodeTable('node'), -1, '...refuses to create a table that exists.');
    ok (defined $s->createNodeTable('test_node_table'), '...creates a table.');
    ok ( ! $DBI::errstr,'...no DBI errors' ) || diag $DBI::errstr; 
}

sub test_nodetable2_add_field_to_table :Test(2) {

    my $self = shift;
    my $s = $self->{ storage };
    ok( $s->addFieldToTable( 'test_node_table',  'foobar', 'int' ), '...returns true.' );
    ok( $s->sqlInsert( 'test_node_table', { foobar => 2 } ), '...inserts value.');

    
}


sub test_nodetable3_drop_field_from_table :Test(2) {

    my $self = shift;
    my $s = $self->{ storage };
    ok( $s->dropFieldFromTable( 'test_node_table', 'foobar' ), '...returns true.' );
    ok ( ! $DBI::errstr,'...no DBI errors' ) || diag $DBI::errstr; 

}


sub test_nodetable4_drop_node_table :Test(1) {
    my $self = shift;
    my $s = $self->{ storage };
    ok( $s->dropNodeTable( 'test_node_table' ), '...returns true.' );

}


sub test_start_rollback_transaction :Test(3) {

    my $self = shift;
    my $s = $self->{ storage };
    is ( $s->startTransaction(), 1, '...returns true.' );
    $s->sqlInsert( 'node', { -createtime => $s->now, title=>'test transaction rollback' } );
    ok( $s->rollbackTransaction(), '...returns true.' );
    ok ( ! $s->sqlSelect( 'title', 'node', "title = 'test transaction rollback'"), '...commit not made.' );
}

sub test_start_commit_transaction :Test(4) {


    my $self = shift;
    my $s = $self->{ storage };
    ok( $s->startTransaction(), '...transaction started.' );
    $s->sqlInsert( 'node', { -createtime => $s->now, title=>'test transaction' } );
    ok( $s->commitTransaction(), '...transaction committed.' );
    ok ( ! $DBI::errstr, '...no DBI errors ') || diag $DBI::errstr;
    is( $s->sqlSelect( 'title', 'node', "title = 'test transaction'"), 'test transaction', '...and still exists.' );


}

## After this test, the node is still unblessed
## Joins on all tables and returns a more 'filled out' hash.
sub test_contstruct_node :Test(1) {


}

sub test_create_group_table :Test(2) {

    my $self = shift;
    my $s = $self->{ storage };
    is( $s->createGroupTable( 'testgrouptable' ),1 , '...creates a group table.' ) || diag $DBI::errstr;
    is( $s->createGroupTable( 'testgrouptable' ), -1 , '...does not create if table exists.' ) || diag $DBI::errstr;

}

sub test_group_table_consistency : Test(2) {

    ## unfortunately can test foreign key violations because sqlite
    ## just exists instead of handing back to this script.

    my $self = shift;
    my $s    = $self->{storage};

    my $err = '';
    local *Everything::logErrors;
    *Everything::logErrors = sub { $err .= "@_"; };

    is(
        $s->sqlInsert(
            'testgrouptable', { node_id => 1, testgrouptable_id => 2 }
        ),
        1,
        '...inserts if id exists.'
    ) || diag $DBI::errstr;

    ok (
        ! $s->sqlInsert(
            'testgrouptable', { node_id => 100, testgrouptable_id => 2, rank => 1 }
        ) ,
        '...no insert on no node.' );

}

sub test_database_exists :Test(1) {

    my $self = shift;
    ok( $self->{ storage }->databaseExists( $self->{ config }->database_name), '... returns true because this database exists.' );
}

sub test_table_exists :Test(3) {
    my $self = shift;
    my $s = $self->{ storage };
    ok( $s->tableExists('node'), '..node table exists.');
    ok( $s->tableExists('nodetype'), '..nodetype table exists.');
    ok( ! $s->tableExists('foobarfoobar'), '..a non-existent table does not exist.');
}


sub test_get_fields_hash :Test(2) {

    my $self = shift;
    my $s = $self->{ storage };
    return unless $s->can('getFieldsHash');
    my @rv = $s->getFieldsHash( 'node', 0 );
    my %rv = map { $_ => 1 } @rv; # we don't care what order they come in

    my @expected = qw/node_id type_nodetype title author_user createtime modified hits loc_location reputation lockedby_user locktime authoraccess groupaccess otheraccess guestaccess dynamicauthor_permission dynamicgroup_permission dynamicother_permission dynamicguest_permission group_usergroup/;
    my %expected = map { $_ => 1 } @expected;

    is_deeply ( \%rv, \%expected, '...returns list of fields in table.' );

    # Strip out everything except for Field in this test
    @rv = map { { Field => $_->{Field} } } sort { $a->{ORDINAL_POSITION} <=> $b->{ORDINAL_POSITION} } $s->getFieldsHash( 'node', 1 );

    my @expected_hashes = map { { Field => $_ } } @expected;

    is_deeply ( \@rv, \@expected_hashes, '...returns list of hashes of fields in table.' );

}

1;
