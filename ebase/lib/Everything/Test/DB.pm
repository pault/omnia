package Everything::Test::DB;

use strict;
use warnings;

use Test::More;
use Test::MockObject;
use Test::MockObject::Extends;
use Scalar::Util qw/blessed/;
use base 'Test::Class';

sub module_class {
    my $self = shift;
    my $name = blessed($self);
    $name =~ s/Test:://;
    return $name;
}

# a useful set of lists
my @lists = ( [qw/one list/], [qw/two list/], [qw/three list/] );

sub startup : Test(startup=>3) {
    my $self  = shift;
    my $class = $self->module_class;
    $self->{class} = $class;
    use_ok($class) || exit;
    can_ok( $class, 'new' );
    isa_ok( $self->{instance} = $class->new, $class );

    $self->fake_dbh();

    ## We need a nodebase object to call against but normally this
    ## instantiates a subclass of this package. But let's pretend we've
    ## done that!

    $self->fake_nodebase();

    ## Mock the cache

    $self->fake_nodecache();

    ## redefine subs that don't exist in this class

    $self->redefine_subs();

}

sub redefine_subs {
  my $self = shift;
  my $class = $self->module_class();
    ## genTableName is implemented in the db specific subclass, perhaps
    ## a dummy method should exist here.  At the moment, let's just
    ## pretend one exists.
    no strict 'refs';
    *{ $class . '::genTableName' } = sub { return $_[1] };

    ## ditto for genLimitString
    *{ $class . '::genLimitString' } = sub {
        my ( $this, $offset, $limit ) = @_;
        $offset ||= 0;
        return "LIMIT $offset, $limit";
    };

    ## and ditto for tableExists
    *{ $class . '::tableExists' } = sub {
        my ( $self, $tablename ) = @_;
        my %existing = ( proserpina => 1, ceres => 1 );
        return 1 if exists $existing{$tablename};
        return 0;
      }

}

sub fixture_reset_stuff :Test(setup) {
  my $self = shift;
  $self->nuke_expected_sql;

  $self->{instance}->{nb}->mock(
        'getNode',
        sub {
            my $node = $self->fake_node();
            $node->{title}   = $_[1];
            $node->{node_id} = 9999;
            return $node;
        }
    );
}

sub fake_dbh {
    my $self = shift;
    $self->{instance}->{dbh} = Test::MockObject->new;
    $self->{instance}->{dbh}->mock( 'quote', sub { qq|'$_[1]'| } );
    $self->{instance}->{dbh}->set_always( 'prepare', $self->{instance}->{dbh});
    $self->{instance}->{dbh}->set_always( 'execute', $self->{instance}->{dbh});
    $self->{instance}->{dbh}->mock( 'fetchrow', sub { qw/a list/ } );

    $self->{instance}->{dbh}->set_true('finish',  'do', '-begin_work', '-rollback', '-commit');

    $self->{instance}->{dbh}->set_false(qw/-err/);
}



sub add_expected_sql {
  my $self = shift;
  $self->{expected_sql} = [] unless @{ $self->{expected_sql}};
  unshift @{ $self->{expected_sql}}, @_;
  return $self;
}

sub nuke_expected_sql {
  my $self = shift;
  $self->{expected_sql} = [];
}

sub shift_expected_sql {
  my $self = shift;
  return shift @{ $self->{expected_sql} };
}

sub isset_expected_sql {
  my $self = shift;
  return 1 if @{ $self->{expected_sql} };
  return 0;
}


my @tablearray = ();

sub fake_node {
    my $self = shift;
    my $n = bless {}, 'Everything::Node';
    my $node = Test::MockObject::Extends->new($n);
    $node->{DB} = $self->{instance}->{nb};
    $node->set_always( 'getTableArray', \@tablearray );
    return $node;
}

sub fake_nodebase {
    my $self = shift;
    require Everything::NodeBase;
    my $nb = bless { storage => $self->{instance} }, 'Everything::NodeBase';
    my $enb = Test::MockObject::Extends->new($nb);
    $enb->mock(
        'getType',
        sub {
            my $node = $self->fake_node();
            $node->{title}   = $_[1];
            $node->{node_id} = 8888;
            return $node;
        }
    );
    $enb->mock(
        'getId',
        sub {
            return $_[1] unless ref $_[1];
            return $_[1]->{node_id};

        }
    );

    $self->{instance}->{nb} = $enb;
    return $self;

}

sub fake_nodecache {
    my $self  = shift;
    my $cache = Test::MockObject->new;
    $self->{instance}->{cache} = $cache;
    $self->fake_nodecache_reset();
    return $self;

}

sub fake_nodecache_reset {
    my $self = shift;
    $self->{instance}->{cache}
      ->set_series( 'getCachedNodeById', { title => 'cached node' }, undef );
    $self->{instance}->{cache}
      ->set_series( 'getCachedNodeByName', { title => 'cached node' }, undef );

}


sub test_gen_where_string : Test(7) {
    my $self  = shift;
    my $class = $self->module_class;

    can_ok( $class, 'genWhereString' );

    ## genWhereString takes two arguments first can be a string or hash
    ## ref
    my $inst = $self->{instance};

    # test parsing an array
    like(
        $inst->genWhereString( { foo => 'bar', 'bar' => 'foo' } ),
        qr/(?:foo='bar'|bar='foo')\s+AND\s+(?:foo='bar'|bar='foo')/sm,
        '...if array is argument.'
    );

    # test parsing array and a type constraint
    like(
        $inst->genWhereString( { foo => 'bar', 'bar' => 'foo' }, 222 ),
qr/(?:foo='bar'|bar='foo')\s+AND\s+(?:foo='bar'|bar='foo')\s+AND\s+type_nodetype=222/sm,
        '...adding a type_nodetype constraint'
    );

    ## Now, we have to test against a node.  Could use the new sqlite
    ## db, but this is sqlite.pm's super class, so we don't know whether
    ## this nor whether sqlite work yet.  Let's just pretend for now.

    my $node = bless { node_id => 333 }, 'Everything::Node';

    like(
        $inst->genWhereString( { foo => 'bar', 'bar' => 'foo' }, $node ),
qr/(?:foo='bar'|bar='foo')\s+AND\s+(?:foo='bar'|bar='foo')\s+AND\s+type_nodetype=333/sm,
        '...adding a node as a type_nodetype constraint'
    );

    # pass a node as a hash value

    # XXXX: obviously we're supposed to pass node_id as the key. This is
    # an interesting "feature" that could fool some people who want to
    # have say 'node' or 'title' as the key.

    is( $inst->genWhereString( { thingo => $node } ),
        qq/thingo='333'/, '...passing a node as a hash value' );

    ### try passing an array ref

    ###  XXX: interesting gotcha here, it isn't obvious that the list
    ###  should be a list of nodes.  But there's no reason why
    ###  someone might not want to pass a list of names title =>
    ###  ['holiday', 'vacation', 'time off' ]

    my $node1 = bless { node_id => 444 }, 'Everything::Node';
    my $node2 = bless { node_id => 555 }, 'Everything::Node';

    is(
        $inst->genWhereString( { thingo => [ $node, $node1, $node2 ] } ),
        qq/(thingo='333' or thingo='444' or thingo='555')/,
        '...passing an array ref as a value'
    );

    ## using '-' when we don't want our values quoted.

    like(
        $inst->genWhereString( { -foo => 'bar', -bar => 'foo' } ),
        qr/(?:foo=bar|bar=foo)\s+AND\s+(?:foo=bar|bar=foo)/sm,
        '...if array is argument.'
    );

}


sub test_fetch_all_nodetype_names : Test(2) {
    my $self   = shift;
    $self->{instance}->{dbh}->clear;

    $self->add_expected_sql('SELECT title FROM node WHERE type_nodetype=1 ORDER BY node_id') unless $self->isset_expected_sql; 
    {
        my @a = @lists;
        $self->{instance}->{dbh}->mock( 'fetchrow_array',
            sub { return unless my $b = shift @a; return @$b } );
    }

    my @result = $self->{instance}->fetch_all_nodetype_names;
    my ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is(
        $args->[1],
        $self->shift_expected_sql(),
        'fetch_all_nodetype_names produces some sql'
    );
    is_deeply( \@result, [qw/one two three/] ),
      '...returns the first arguments from the array';
}

sub test_get_database_handle : Test(1) {
    my $self = shift;
    is_deeply(
        $self->{instance}->getDatabaseHandle,
        $self->{instance}->{dbh},
        'getDatabaseHandle returns the DBI object'
    );

}

sub test_last_value : Test(1) {
    my $self = shift;

    ## This just calls last_insert_id on the database
    ## handle. Obviously this should be overriden by sub-classes and
    ## is database dependent.  So, there may possibly be some
    ## gotchas. We'll just use our mocked objects here. mysql.pm users
    ## this one.  postgres.pm probably shouldn't.

    $self->{instance}->{dbh}->set_always( 'last_insert_id', 555 );
    is( $self->{instance}->lastValue,
        555, 'lastValue should return the last insert id' );

}

sub test_sql_delete : Test(2) {
    my $self  = shift;
    my $value = 'a value';

    $self->add_expected_sql('DELETE FROM atable WHERE foo="bar"')  unless $self->isset_expected_sql;


    ## This one only takes three arguments
    my @args = ( 'atable', 'foo="bar"', [$value] );
    $self->{instance}->{dbh}->clear;
    my $cursor = $self->{instance}->sqlDelete(@args);
    my ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is(
        $args->[1],
        $self->shift_expected_sql,
        'sqlDelete creates some sql, we test it.'
    );
    is( $cursor, $self->{instance}->{dbh}, '...and returns a value.' );

}

sub test_sql_select : Test(3) {
    my $self  = shift;

    $self->add_expected_sql('SELECT node FROM atable WHERE title = ? ORDER BY title')  unless $self->isset_expected_sql;


    my $value = 'a value';
    my @args  = ( 'node', 'atable', 'title = ?', 'ORDER BY title', [$value] );

    my @rows = ( [qw/one list/], [qw/two list/], [qw/three list/] );
    my @other_rows = @rows;
    $self->{instance}->{dbh}
      ->mock( 'fetchrow', sub { return shift @other_rows } );
    $self->{instance}->{dbh}->clear;
 
    my $result = $self->{instance}->sqlSelect(@args);
    my ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is(
        $args->[1],
        $self->shift_expected_sql,
        'sqlSelect creates some sql, we test it.'
    );
    ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is( $method, 'execute', '...calls execute on the DBI' );

    is_deeply( $result, $rows[0], '...test that exceute returns something' );
}

sub test_sql_select_joined : Test(4) {
    my $self  = shift;

    $self->add_expected_sql(qr/SELECT node FROM atable LEFT JOIN (?:foo|one) ON (?:bar|two) LEFT JOIN (?:foo|one) ON (?:bar|two) WHERE title = \? ORDER BY title/) unless $self->isset_expected_sql;
    my $value = 'a value';

    my @args = (
        'node', 'atable', { foo => 'bar', one => 'two' },
        'title = ?',
        'ORDER BY title',
        [ \$value ]
    );
    $self->{instance}->{dbh}->clear;
    my $cursor = $self->{instance}->sqlSelectJoined(@args);
    my ( $method, $args ) = $self->{instance}->{dbh}->next_call();
    like(
        $args->[1],
	 $self->shift_expected_sql,
        'sqlSelectJoined makes some sql'
    );
    is( $method, 'prepare', '...it calls prepare on the DBI' );
    ( $method, $args ) = $self->{instance}->{dbh}->next_call();
    is( $method, 'execute', '...it calls execute on the DBI' );
    is_deeply( $cursor, $args->[0], '...returns the cursor' );
}

sub test_sql_select_many : Test(2) {
    my $self  = shift;

    $self->add_expected_sql('SELECT node FROM atable WHERE title = ? ORDER BY title') unless $self->isset_expected_sql;

    my $value = 'a value';
    my @args = ( 'node', 'atable', 'title = ?', 'ORDER BY title', [ \$value ] );    $self->{instance}->{dbh}->clear;
    my $cursor = $self->{instance}->sqlSelectMany(@args);
    my ( $method, $args ) = $self->{instance}->{dbh}->next_call();
    is(
        $args->[1],
        $self->shift_expected_sql,
        'sqlSelectMany creates some sql, we test it.'
    );
    is_deeply(
        $cursor,
        $self->{instance}->{dbh},
        '...it then executes against the DBI object'
    );
}

sub test_sql_select_hashref : Test(4) {
    my $self  = shift;

    $self->add_expected_sql('SELECT node FROM atable WHERE title = ? ORDER BY title') unless $self->isset_expected_sql;
    my $value = 'a value';

    my @args = ( 'node', 'atable', 'title = ?', 'ORDER BY title', [ \$value ] );
    $self->{instance}->{dbh}->clear;
    $self->{instance}->{dbh}
      ->set_always( 'fetchrow_hashref', { title => 'wow', bright => 'sky' } );

    my $cursor = $self->{instance}->sqlSelectHashref(@args);
    my ($method, $args) =  $self->{instance}->{dbh}->next_call; 
   is(
        $args->[1],
        $self->shift_expected_sql,
        'sqlSelectHashref makes some sql'
    );
    is( $method, 'prepare', '...it calls prepare on the DBI' );
    ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is( $method, 'execute', '...it calls execute on the DBI' );
    is_deeply(
        $cursor,
        { title => 'wow', bright => 'sky' },
        '...returns a hashref'
    );

}

sub test_sql_update : Test(6) {
    my $self  = shift;

    $self->add_expected_sql(qr/UPDATE atable SET foo = \?\s+WHERE title = \?/ms) unless $self->isset_expected_sql;

    my $value = 'a value'; 
    my @args = ( 'atable', { foo => 'bar' }, 'title = ?', [$value] );
    $self->{instance}->{dbh}->clear;
    my $cursor = $self->{instance}->sqlUpdate(@args);
    my ($method, $args) =  $self->{instance}->{dbh}->next_call;
    like(
        $args->[1],
        $self->shift_expected_sql,
        'sqlUpdate makes some sql'
    );
    is( $method, 'prepare', '...it calls prepare on the DBI' );
    ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is( $method, 'execute', '...it calls execute on the DBI' );
    is( $args->[1], 'bar',     '...check bound values' );
    is( $args->[2], 'a value', '...check bound values' );
    ok($cursor);
}

sub test_sql_insert : Test(2) {
    my $self  = shift;
    my $value = 'a value';

    $self->add_expected_sql(qr/INSERT INTO atable \((?:one|foo), (?:one|foo)\) VALUES\(\?, \?\)/ )  unless $self->isset_expected_sql;

    ## takes a table name and then a hash for the where clause
    my @args = ( 'atable', { foo => 'bar', one => 'two' } );
    $self->{instance}->{dbh}->clear;
    my $cursor = $self->{instance}->sqlInsert(@args);
    my ($method, $args) =  $self->{instance}->{dbh}->next_call;
    like( $args->[1],
        $self->shift_expected_sql);

    ## returns true on success;
    ok($cursor);
}

sub test_quote_data : Test(6) {
    my $self  = shift;
    my $data  = { foo => ' bar', good => 'day', -to => 'you' };
    my $bound = { foo => '?', good => '?', to => 'you' };
    my $value = { foo => ' bar', good => 'day', -to => undef };
    my @rv    = $self->{instance}->_quoteData($data);
    my $index = 0;
    foreach ( 0 .. $#{ $rv[0] } ) {
        my $name = $rv[0]->[$_];

        #bound
        is( $rv[1]->[$_], $$bound{$name},
            '_quoteData must correctly return the bound variable' );

        #value
        is( $rv[2]->[$_], $$value{$name},
            '_quoteData correctly returns the value' );

    }

}

sub test_sql_execute : Test(2) {
    my $self  = shift;
    my $value = 'a value';

    ## This one takes some sql and the bound values;
    my @args = ( 'SELECT something FROM nothing WHERE ?', [$value] );
    $self->{instance}->{dbh}->clear;
    my $cursor = $self->{instance}->sqlExecute(@args);
    my ( $method, $args ) = $self->{instance}->{dbh}->next_call();
    is( $args->[1], 'SELECT something FROM nothing WHERE ?' );

    ## should return true
    ok($cursor);

}

sub test_get_node_by_id_new : Test(5) {
    my $self = shift;

    $self->fake_nodecache_reset();

    $self->add_expected_sql('SELECT * FROM node WHERE node_id=2 ')  unless $self->isset_expected_sql;

    $self->{instance}->{dbh}->set_always( 'fetchrow_hashref', { title => 'wow', bright => 'sky' } );
    my $rv = $self->{instance}->getNodeByIdNew(0);
    is( $rv->{title}, '/', 'getNodeByIdNew can return the zero node' );

    $self->{instance}->{dbh}->clear;
    $rv = $self->{instance}->getNodeByIdNew(2);
    my ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is( $method, 'prepare', '...otherwise calls prepare on DBI' );
    is(
        $args->[1],
       $self->shift_expected_sql,
        '...and prepares some sql'
    );
    ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is( $method, 'execute', '...then calls execute.' );

    ## here it calls fetchrow_hashref directly on the cursor, is this
    ## the best way to do it?
    is( $rv->{title}, 'wow', '... and gets a node (we hope)' );
}

sub test_construct_node : Test(5) {

    ## The purpose of this is to fill out a node object that is a mere
    ## skeleton having been constructed from the node table. Hence, it
    ## wants a semi-contstructed node passed as an argument
    my $self = shift;
    
    $self->add_expected_sql('SELECT * FROM table2 LEFT JOIN table1 ON table2_id=table1_id WHERE table2_id=100 ')  unless $self->isset_expected_sql;

    my $node = { type_nodetype => 99, node_id => 100 };
    @tablearray = ();
    is( $self->{instance}->constructNode($node),
        undef, 'constructNode returns undef if no tables are available' );
    $self->{instance}->{dbh}->clear;
    @tablearray = (qw/table1 table2/);
    $self->{instance}->{dbh}
      ->set_always( 'fetchrow_hashref', { title => 'wow', bright => 'sky' } );

    is( $self->{instance}->constructNode($node),
        1, '...and returns true if there are.' );

   my ($method, $args) =  $self->{instance}->{dbh}->next_call; 
   is( $method, 'prepare', '...it calls prepare on DBI' );
    is(
        $args->[1],
       $self->shift_expected_sql(),
        '...and prepares some sql'
    );
    is( $node->{bright}, 'sky',
        '...and completes construction of the node object' );
}

sub test_get_node_by_name : Test(4) {
    my $self = shift;

    $self->add_expected_sql(q|SELECT * FROM node WHERE title='agamemnon' AND type_nodetype=9999 |,)  unless $self->isset_expected_sql;


    ## This one requires node name and node types as arguments

    ## It returns under of the type param is missing. (But oddly not if
    ## the 'name' param is).

    is( $self->{instance}->getNodeByName('icarus'),
        undef, 'getNodeByName returns undef if we forgot to include a type' );

    ## Now we don't
    $self->{instance}->{dbh}->clear;
    is(
        ref $self->{instance}->getNodeByName(
            'agamemnon', { title => 'menelaos', node_id => 333 }
        ),
        'HASH',
        '...but returns a node if we specify both arguments'
    );
    my ($method, $args) =  $self->{instance}->{dbh}->next_call(2);

    is( $method, 'prepare', '...it calls prepare on DBI' );
    is(
        $args->[1],
       $self->shift_expected_sql,
        '...and prepares some sql'
    );

}

sub test_get_node_cursor : Test(4) {
    my $self  = shift;
    my $value = 'a value';
    $self->add_expected_sql( q|SELECT fieldname FROM node LEFT JOIN lions ON node_id=lions_id LEFT JOIN serpents ON node_id=serpents_id WHERE foo='bar' AND type_nodetype=8888 ORDER BY title LIMIT 2, 1|)  unless $self->isset_expected_sql;
    @tablearray = (qw{serpents lions});
    my @args = ( 'fieldname', { foo => 'bar' }, 'sometype', 'title', 1, 2 );
    $self->{instance}->{dbh}->clear;
    my $cursor = $self->{instance}->getNodeCursor(@args);
    my ($method, $args) =  $self->{instance}->{dbh}->next_call(2);
 
    is(
        $args->[1],
        $self->shift_expected_sql(),
        'getNodeCursor makes some sql'
    );
    is( $method, 'prepare', '...it calls prepare on the DBI' );
    ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is( $method, 'execute', '...it calls execute on the DBI' );
    is_deeply( $cursor, $args->[0], '...returns the cursor' );

}

sub test_select_node_where : Test(6) {
    my $self  = shift;

    $self->add_expected_sql(q|SELECT node_id FROM node LEFT JOIN sylph ON node_id=sylph_id LEFT JOIN dryad ON node_id=dryad_id WHERE medusa='arachne' AND type_nodetype=8888 ORDER BY title LIMIT 2, 1|)  unless $self->isset_expected_sql;

    my $value = 'a value';
    @tablearray = (qw{dryad sylph});

    # the args we want are: $WHERE, $TYPE, $orderby, $limit, $offset,
    # $refTotalRows, $nodeTableOnly

    my @rows = ( [qw/one list/], [qw/two list/], [qw/three list/] );
    my @other_rows = @rows;
    $self->{instance}->{dbh}
      ->mock( 'fetchrow', sub { return shift @other_rows } );

    my @args = ( { medusa => 'arachne' }, 111, 'title', 1, 2 );

    $self->{instance}->{dbh}->clear;
    my $nodelist = $self->{instance}->selectNodeWhere(@args);
    my ($method, $args) =  $self->{instance}->{dbh}->next_call(2);

    is(
        $args->[1],
        $self->shift_expected_sql,
        'getNodeCursor makes some sql'
    );
    is( $method, 'prepare', '...it calls prepare on the DBI' );
    ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is( $method, 'execute', '...it calls execute on the DBI' );
    is( ref $nodelist,  'ARRAY',   '...returns an array ref' );
    is( @$nodelist,     3,         '...returns the right number of items' );
    is_deeply( $nodelist, \@rows, '...and the right items' );

}

sub test_count_node_matches : Test(4) {
    my $self  = shift;
    $self->add_expected_sql (q|SELECT count(*) FROM node LEFT JOIN lions ON node_id=lions_id LEFT JOIN serpents ON node_id=serpents_id WHERE foo='bar' AND type_nodetype=8888 |)  unless $self->isset_expected_sql;

    my $value = 'a value';
    @tablearray = (qw{serpents lions});
    $self->{instance}->{dbh}->set_always( 'fetchrow', 3 );

    ## tables a WHERE hash and a type
    my @args = ( { foo => 'bar' }, 'sometype' );
    $self->{instance}->{dbh}->clear;
    my $rv = $self->{instance}->countNodeMatches(@args);
    my ($method, $args) =  $self->{instance}->{dbh}->next_call(2);

    is(
        $args->[1],
       $self->shift_expected_sql,
        'countNodeMatches makes some sql'
    );
    is( $method, 'prepare', '...it calls prepare on the DBI' );
    ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is( $method, 'execute', '...it calls execute on the DBI' );
    is( $rv,            3,         '...and returns the correct number.' );

}

sub test_get_all_types : Test(10) {

    ### This calls the Nodebase function getNode.  Arguably, it
    ### shouldn't as this is a DB function. Naughty.
    my $self  = shift;

    $self->add_expected_sql (q|SELECT node_id FROM node WHERE type_nodetype=1 |)  unless $self->isset_expected_sql;

    my $value = 'a value';
    @tablearray = (qw{serpents lions});
    $self->{instance}->{dbh}->set_series( 'fetchrow', 1, 2, 3, 5, 8, 11 )
      ->set_always( 'fetchrow_hashref', { title => 'wow', bright => 'sky' } );

    ## tables a WHERE hash and a type
    my @args = ( { foo => 'bar' }, 'sometype' );

    $self->{instance}->{dbh}->clear;
    my @rv = $self->{instance}->getAllTypes(@args);
    my ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is(
        $args->[1],
       $self->shift_expected_sql,
        'getAllTypes makes some sql'
    );

    is( $method, 'prepare', '...it calls prepare on the DBI' );
    ($method, $args) =  $self->{instance}->{dbh}->next_call;
    is( $method, 'execute', '...it calls execute on the DBI' );

    # this returns stuff created by getNodeByIdNew and in the test
    # environment returns hashes.
    is( scalar @rv, 6, '...and returns the correct arguments.' );

    # test that all returned items are proper nodes;
    foreach (@rv) {
	isa_ok($_, 'Everything::Node');
    }

}

sub test_drop_node_table : Test(18) {
    my $self     = shift;
    my $instance = $self->{instance};
    $self->add_expected_sql('drop table proserpina') unless $self->isset_expected_sql;
    # this takes one argument which is the table name.

    my @nodrop =
      qw(container document htmlcode htmlpage image links maintenance node nodegroup nodelet nodetype note rating user);

    foreach (@nodrop) {
        ## returns a zero.  Wouldn't it be better to return undef on failure?
        is( $instance->dropNodeTable($_),
            0, "dropNodeTable must not drop a $_ table." );
    }

    ## try to drop a table:

    is( $instance->dropNodeTable('vulcan'),
        0, '...we can\'t drop tables that don\'t exist.' );

    ## drop an existing table
    ### check sql
    $self->{instance}->{dbh}->clear;
    my $rv = $instance->dropNodeTable('proserpina');
    my $method =  $self->{instance}->{dbh}->call_pos(-1);
    my @args =  $self->{instance}->{dbh}->call_args(-1);
    is ($method, 'do', '....calls "do" against DBI.');
    is ($args[1], $self->shift_expected_sql, '...creates some sql.');
    is( $rv, 1, '...returns success.');

}

sub test_quote : Test(1) {
    my $self = shift;
    is( $self->{instance}->quote('hello'),
        q{'hello'}, 'quote is passed directly to the DBI object' );

}

sub test_fix_node_keys : Test(1) {
    my $self = shift;
    is( $self->{instance}->fix_node_keys,
        undef, 'fix_node_keys is subclass responsibility' );

}

sub test_get_nodetype_tables : Test( 7 ) {

    my $self     = shift;
    my $instance = $self->{instance};
    my $storage  = $instance->{storage};

    ok( !$instance->getNodetypeTables(),
        'getNodetypeTables() should return false without type' );

    is_deeply( $instance->getNodetypeTables(1),
        ['nodetype'], '... and should return nodetype given nodetype id' );

    is_deeply( $instance->getNodetypeTables( { node_id => 1 } ),
        ['nodetype'], '... or nodetype node' );

    is_deeply(
        $instance->getNodetypeTables( { title => 'nodemethod', node_id => 0 } ),
        ['nodemethod'],
        '... or should return nodemethod if given nodemethod node'
    );

    @tablearray = qw( foo bar );
    is_deeply( $instance->getNodetypeTables('bar'),
        [qw( foo bar )], '... or calling getTableArray() on promoted node' );
    @tablearray = ();
    is_deeply( $instance->getNodetypeTables('baz'),
        [], '... returning nothing if there are no nodetype tables' );

    is_deeply( $instance->getNodetypeTables( 'flaz', 1 ),
        ['node'], '... but adding node if addNode flag is true' );
}

sub test_parse_sql_file :Test(2){
    my $self = shift;
    my $instance = $self->{instance};
    use File::Temp qw/tempfile/;
    my $fh = tempfile(UNLINK => 1);

    my $sql = <<SQL;
BEGIN TRANSACTION;


--
-- Table: mail
--
DROP TABLE IF EXISTS mail;
CREATE TABLE mail (
-- Comments:
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:35 2004
-- Table: mail
--

  mail_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  from_address char(80) NOT NULL DEFAULT ''
);


--
-- Table: image
--
DROP TABLE IF EXISTS image;
CREATE TABLE image (
-- Comments:
-- Created by SQL::Translator::Producer::PostgreSQL
-- Created on Mon Jun 14 12:06:09 2004
-- Table: image
--

  image_id INTEGER PRIMARY KEY NOT NULL,
  src varchar(255),
  alt varchar(255),
  thumbsrc varchar(255),
  description text
);

SQL

my @expected= ('BEGIN TRANSACTION',
'DROP TABLE IF EXISTS mail',
q{CREATE TABLE mail (
  mail_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  from_address char(80) NOT NULL DEFAULT ''
)},
'DROP TABLE IF EXISTS image',
'CREATE TABLE image (
  image_id INTEGER PRIMARY KEY NOT NULL,
  src varchar(255),
  alt varchar(255),
  thumbsrc varchar(255),
  description text
)');


print $fh $sql;
$fh->seek(0,0);
ok(my @rv = $instance->parse_sql_file($fh), '...should parse OK.');
is_deeply(\@rv, \@expected, '...splits the sql into manageable portions.');


}

1;
