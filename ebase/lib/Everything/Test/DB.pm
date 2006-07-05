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

# a place to keep sql calls my prepare and execute
my @calls;

sub startup : Test(startup=>3) {
    my $self  = shift;
    my $class = $self->module_class;
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

sub fake_dbh {
    my $self = shift;
    $self->{instance}->{dbh} = Test::MockObject->new;
    $self->{instance}->{dbh}->mock( 'quote', sub { qq|'$_[1]'| } );
    $self->{instance}->{dbh}->mock( 'prepare',
        sub { push @calls, [ 'prepare', $_[0], $_[1] ]; return $_[0] } );
    $self->{instance}->{dbh}
      ->mock( 'execute', sub { push @calls, [ 'execute', @_ ]; return $_[0] } );
    $self->{instance}->{dbh}->mock( 'fetchrow', sub { qw/a list/ } );
    {
        my @a = @lists;
        $self->{instance}->{dbh}->mock( 'fetchrow_array',
            sub { return unless my $b = shift @a; return @$b } );
    }
    $self->{instance}->{dbh}
      ->set_always( 'fetchrow_hashref', { title => 'wow', bright => 'sky' } );
    $self->{instance}->{dbh}->set_true('finish');
    $self->{instance}->{dbh}->mock( 'do', sub { $_[1] } );

}

my @tablearray = ();

sub fake_node {
    my $self = shift;

    my $node = Test::MockObject->new;
    $node->set_always( 'getTableArray', \@tablearray );
    return $node;
}

sub fake_nodebase {
    my $self = shift;
    require Everything::NodeBase;
    my $nb = bless { storage => $self->{instance} }, 'Everything::NodeBase';
    my $enb = Test::MockObject::Extends->new($nb);
    $enb->mock(
        'getNode',
        sub {
            my $node = $self->fake_node();
            $node->{title}   = $_[1];
            $node->{node_id} = 9999;
            return $node;
        }
    );
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

sub fixture_zap_stuff : Test(setup) {
    @calls = ();

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
    my @result = $self->{instance}->fetch_all_nodetype_names;

    is(
        $calls[0]->[2],
        'SELECT title FROM node WHERE type_nodetype=1 ',
        'fetch_all_nodetype_names produces some sql'
    );
    is_deeply( \@result, [qw/one two three/] ),
      '...returns the first arguments from the array';
}

sub test_getDatabaseHandle : Test(1) {
    my $self = shift;
    is_deeply(
        $self->{instance}->getDatabaseHandle,
        $self->{instance}->{dbh},
        'getDatabaseHandle returns the DBI object'
    );

}

sub test_lastValue : Test(1) {
    my $self = shift;

    ## This just calls last_insert_id on the database handle. Obviously
    ## this should be overriden by sub-classes and is database
    ## dependent.  So, there may possibly be some gotchas. We'll just
    ## use our mocked objects here.

    $self->{instance}->{dbh}->set_always( 'last_insert_id', 555 );
    is( $self->{instance}->lastValue,
        555, 'lastValue should return the last insert id' );

}

sub test_sqlDelete : Test(2) {
    my $self  = shift;
    my $value = 'a value';

    ## This one only takes three arguments
    my @args = ( 'atable', 'foo="bar"', [$value] );
    my $cursor = $self->{instance}->sqlDelete(@args);
    is(
        $calls[0]->[2],
        'DELETE FROM atable WHERE foo="bar"',
        'sqlDelete creates some sql, we test it.'
    );
    is( $cursor, $self->{instance}->{dbh}, '...and returns a value.' );

}

sub test_sqlSelect : Test(3) {
    my $self  = shift;
    my $value = 'a value';
    my @args  = ( 'node', 'atable', 'title = ?', 'ORDER BY title', [$value] );

    my @rows = ( [qw/one list/], [qw/two list/], [qw/three list/] );
    my @other_rows = @rows;
    $self->{instance}->{dbh}
      ->mock( 'fetchrow', sub { return shift @other_rows } );

    my $result = $self->{instance}->sqlSelect(@args);

    is(
        $calls[0]->[2],
        'SELECT node FROM atable WHERE title = ? ORDER BY title',
        'sqlSelect creates some sql, we test it.'
    );
    is( $calls[1]->[0], 'execute', '...calls execute on the DBI' );

    is_deeply( $result, $rows[0], '...test that exceute returns something' );
}

sub test_sqlSelectJoined : Test(4) {
    my $self  = shift;
    my $value = 'a value';

    my @args = (
        'node', 'atable', { foo => 'bar', one => 'two' },
        'title = ?',
        'ORDER BY title',
        [ \$value ]
    );
    my $cursor = $self->{instance}->sqlSelectJoined(@args);
    like(
        $calls[0]->[2],
qr/SELECT node FROM atable LEFT JOIN (?:foo|one) ON (?:bar|two) LEFT JOIN (?:foo|one) ON (?:bar|two) WHERE title = \? ORDER BY title/,
        'sqlSelectJoined makes some sql'
    );
    is( $calls[0]->[0], 'prepare', '...it calls prepare on the DBI' );
    is( $calls[1]->[0], 'execute', '...it calls execute on the DBI' );
    is_deeply( $cursor, $calls[1]->[1], '...returns the cursor' );

}

sub test_sqlSelectMany : Test(2) {
    my $self  = shift;
    my $value = 'a value';
    my @args = ( 'node', 'atable', 'title = ?', 'ORDER BY title', [ \$value ] );
    my $cursor = $self->{instance}->sqlSelectMany(@args);
    is(
        $calls[0]->[2],
        'SELECT node FROM atable WHERE title = ? ORDER BY title',
        'sqlSelectMany creates some sql, we test it.'
    );
    is_deeply(
        $cursor,
        $self->{instance}->{dbh},
        '...it then executes against the DBI object'
    );
}

sub test_sqlSelectHashref : Test(4) {
    my $self  = shift;
    my $value = 'a value';

    my @args = ( 'node', 'atable', 'title = ?', 'ORDER BY title', [ \$value ] );
    my $cursor = $self->{instance}->sqlSelectHashref(@args);
    is(
        $calls[0]->[2],
        'SELECT node FROM atable WHERE title = ? ORDER BY title',
        'sqlSelectHashref makes some sql'
    );
    is( $calls[0]->[0], 'prepare', '...it calls prepare on the DBI' );
    is( $calls[1]->[0], 'execute', '...it calls execute on the DBI' );
    is_deeply(
        $cursor,
        { title => 'wow', bright => 'sky' },
        '...returns a hashref'
    );

}

sub test_sqlUpdate : Test(6) {
    my $self  = shift;
    my $value = 'a value';

    my @args = ( 'atable', { foo => 'bar' }, 'title = ?', [$value] );
    my $cursor = $self->{instance}->sqlUpdate(@args);
    like(
        $calls[0]->[2],
        qr/UPDATE atable SET foo = \?\s+WHERE title = \?/ms,
        'sqlUpdate makes some sql'
    );
    is( $calls[0]->[0], 'prepare', '...it calls prepare on the DBI' );
    is( $calls[1]->[0], 'execute', '...it calls execute on the DBI' );
    is( $calls[1]->[2], 'bar',     '...check bound values' );
    is( $calls[1]->[3], 'a value', '...check bound values' );
    ok($cursor);

}

sub test_sqlInsert : Test(2) {
    my $self  = shift;
    my $value = 'a value';

    ## takes a table name and then a hash for the where clause
    my @args = ( 'atable', { foo => 'bar', one => 'two' } );
    my $cursor = $self->{instance}->sqlInsert(@args);
    like( $calls[0]->[2],
        qr/INSERT INTO atable \((?:one|foo), (?:one|foo)\) VALUES\(\?, \?\)/ );

    ## returns true on success;
    ok($cursor);

}

sub test_quoteData : Test(6) {
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

sub test_sqlExecute : Test(2) {
    my $self  = shift;
    my $value = 'a value';

    ## This one takes some sql and the bound values;
    my @args = ( 'SELECT something FROM nothing WHERE ?', [$value] );
    my $cursor = $self->{instance}->sqlExecute(@args);
    is( $calls[0]->[2], 'SELECT something FROM nothing WHERE ?' );

    ## should return true
    ok($cursor);

}

sub test_getNodeByIdNew : Test(6) {
    my $self = shift;

    $self->fake_nodecache_reset();
    my $rv = $self->{instance}->getNodeByIdNew(0);
    is( $rv->{title}, '/', 'getNodeByIdNew can return the zero node' );
    $rv = $self->{instance}->getNodeByIdNew(1);
    is( $rv->{title}, 'cached node', '... can return a cached node' );
    $rv = $self->{instance}->getNodeByIdNew(2);
    is( $calls[0]->[0], 'prepare', '...otherwise calls prepare on DBI' );
    is(
        $calls[0]->[2],
        'SELECT * FROM node WHERE node_id=2 ',
        '...and prepares some sql'
    );
    is( $calls[1]->[0], 'execute', '...then calls execute.' );

    ## here it calls fetchrow_hashref directly on the cursor, is this
    ## the best way to do it?
    is( $rv->{title}, 'wow', '... and gets a node (we hope)' );
}

sub test_constructNode : Test(5) {

    ## The purpose of this is to fill out a node object that is a mere
    ## skeleton having been constructed from the node table. Hence, it
    ## wants a semi-contstructed node passed as an argument
    my $self = shift;
    my $node = { type_nodetype => 99, node_id => 100 };
    @tablearray = ();
    is( $self->{instance}->constructNode($node),
        undef, 'constructNode returns undef if no tables are available' );

    @tablearray = (qw/table1 table2/);
    is( $self->{instance}->constructNode($node),
        1, '...and returns true if there are.' );
    is( $calls[0]->[0], 'prepare', '...it calls prepare on DBI' );
    is(
        $calls[0]->[2],
'SELECT * FROM table2 LEFT JOIN table1 ON table2_id=table1_id WHERE table2_id=100 ',
        '...and prepares some sql'
    );
    is( $node->{bright}, 'sky',
        '...and completes construction of the node object' );
}

sub test_getNodeByName : Test(5) {
    my $self = shift;
    ## This one requires node name and node types as arguments

    ## It returns under of the type param is missing. (But oddly not if
    ## the 'name' param is).

    is( $self->{instance}->getNodeByName('icarus'),
        undef, 'getNodeByName returns undef if we forgot to include a type' );

    # we get in from the cache
    is(
        $self->{instance}->getNodeByName( 'icarus', 'pegasus' )->{title},
        'cached node',
        'getNodeByName returns undef if we forgot to include a type'
    );

    ## Now we don't
    is(
        ref $self->{instance}->getNodeByName(
            'agamemnon', { title => 'menelaos', node_id => 333 }
        ),
        'HASH',
        '...but returns a node if we specify both arguments'
    );
    is( $calls[0]->[0], 'prepare', '...it calls prepare on DBI' );
    is(
        $calls[0]->[2],
        q|SELECT * FROM node WHERE title='agamemnon' AND type_nodetype=9999 |,
        '...and prepares some sql'
    );

}

sub test_getNodeCursor : Test(4) {
    my $self  = shift;
    my $value = 'a value';
    @tablearray = (qw{serpents lions});
    my @args = ( 'fieldname', { foo => 'bar' }, 'sometype', 'title', 1, 2 );
    my $cursor = $self->{instance}->getNodeCursor(@args);
    is(
        $calls[0]->[2],
q|SELECT fieldname FROM node LEFT JOIN lions ON node_id=lions_id LEFT JOIN serpents ON node_id=serpents_id WHERE foo='bar' AND type_nodetype=8888 ORDER BY title LIMIT 2, 1|,
        'getNodeCursoer makes some sql'
    );
    is( $calls[0]->[0], 'prepare', '...it calls prepare on the DBI' );
    is( $calls[1]->[0], 'execute', '...it calls execute on the DBI' );
    is_deeply( $cursor, $calls[1]->[1], '...returns a the cursor' );

}

sub test_selectNodeWhere : Test(6) {
    my $self  = shift;
    my $value = 'a value';
    @tablearray = (qw{dryad sylph});

    # the args we want are: $WHERE, $TYPE, $orderby, $limit, $offset,
    # $refTotalRows, $nodeTableOnly

    my @rows = ( [qw/one list/], [qw/two list/], [qw/three list/] );
    my @other_rows = @rows;
    $self->{instance}->{dbh}
      ->mock( 'fetchrow', sub { return shift @other_rows } );

    my @args = ( { medusa => 'arachne' }, 111, 'title', 1, 2 );
    my $nodelist = $self->{instance}->selectNodeWhere(@args);
    is(
        $calls[0]->[2],
q|SELECT node_id FROM node LEFT JOIN sylph ON node_id=sylph_id LEFT JOIN dryad ON node_id=dryad_id WHERE medusa='arachne' AND type_nodetype=8888 ORDER BY title LIMIT 2, 1|,
        'getNodeCursoer makes some sql'
    );
    is( $calls[0]->[0], 'prepare', '...it calls prepare on the DBI' );
    is( $calls[1]->[0], 'execute', '...it calls execute on the DBI' );
    is( ref $nodelist,  'ARRAY',   '...returns an array ref' );
    is( @$nodelist,     3,         '...returns the right number of items' );
    is_deeply( $nodelist, \@rows, '...and the right items' );

}

sub test_countNodeMatches : Test(4) {
    my $self  = shift;
    my $value = 'a value';
    @tablearray = (qw{serpents lions});
    $self->{instance}->{dbh}->set_always( 'fetchrow', 3 );

    ## tables a WHERE hash and a type
    my @args = ( { foo => 'bar' }, 'sometype' );
    my $rv = $self->{instance}->countNodeMatches(@args);
    is(
        $calls[0]->[2],
q|SELECT count(*) FROM node LEFT JOIN lions ON node_id=lions_id LEFT JOIN serpents ON node_id=serpents_id WHERE foo='bar' AND type_nodetype=8888 |,
        'countNodeMatches makes some sql'
    );
    is( $calls[0]->[0], 'prepare', '...it calls prepare on the DBI' );
    is( $calls[1]->[0], 'execute', '...it calls execute on the DBI' );
    is( $rv,            3,         '...and returns the correct number.' );

}

sub test_getAllTypes : Test(4) {

    ### This calls the Nodebase function getNode.  Arguably, it
    ### shouldn't as this is a DB function. Naughty.
    my $self  = shift;
    my $value = 'a value';
    @tablearray = (qw{serpents lions});
    $self->{instance}->{dbh}->set_series( 'fetchrow', 1, 2, 3, 5, 8, 11 );

    ## tables a WHERE hash and a type
    my @args = ( { foo => 'bar' }, 'sometype' );
    my @rv = $self->{instance}->getAllTypes(@args);
    is(
        $calls[0]->[2],
        q|SELECT node_id FROM node WHERE type_nodetype=1 |,
        'getAllTypes makes some sql'
    );
    is( $calls[0]->[0], 'prepare', '...it calls prepare on the DBI' );
    is( $calls[1]->[0], 'execute', '...it calls execute on the DBI' );

    # this returns stuff created by getNodeByIdNew and in the test
    # environment returns hashes.
    is( scalar @rv, 6, '...and returns the correct arguments.' );

}

sub test_dropNodeTable : Test(16) {
    my $self     = shift;
    my $instance = $self->{instance};

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

    is(
        $instance->dropNodeTable('proserpina'),
        'drop table proserpina',
        '...we can drop tables that do exist.'
    );

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

1;
