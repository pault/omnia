package Everything::Test::Nodeball;

use Test::More;
use Test::MockObject;
use Test::Exception;
use Test::Warn;
use Scalar::Util qw/blessed/;
use SUPER;
use File::Temp;
use IO::File;
use IO::Dir;
use File::Spec;
use File::Path;
use base 'Everything::Test::Abstract';
use strict;
use warnings;

sub startup : Test(startup => +0) {
    my $self = shift;
    $self->SUPER;
    my $pkg  = $self->{class};
    my $mock = Test::MockObject->new;
    no strict 'refs';
    *{ $pkg . '::DB' } = \$mock;
    use strict 'refs';
    $self->{mock} = $mock;
}

## takes options -u -p -h and -v first arg is an array ref of
## defaults, second is ref to args passed by the command like
##
## XXXX: funtion should be fixed so not to use package var. This could
## introduce errors.
sub test_setup_options : Test(4) {
    my $self = shift;
    can_ok( $self->{class}, 'setupOptions' )
      || return 'setupOptions not implemented.';
    my $instance = $self->{instance};
    my $class    = $self->{class};
    no strict 'refs';
    local *setupOptions;
    *setupOptions = *{ $class . '::setupOptions' };
    my @opts = ( -h => '123.1', -u => 'me', qw/-v -p hello/ );
    setupOptions( undef, \@opts );
    is_deeply(
        \%{ $class . '::OPTIONS' },
        { host => '123.1', user => 'me', verbose => 1, password => 'hello' },
        '..test h, v, p and u'
    );
    @opts = (qw/-v -p hello/);
    %{ $class . '::OPTIONS' } = ();
    my $defaults = { password => 1, user => 2, verbose => 1, host => 3 };
    setupOptions( $defaults, [] );
    is_deeply( \%{ $class . '::OPTIONS' }, $defaults, '...test defaults' );

    %{ $class . '::OPTIONS' } = ();    # clear options
    setupOptions( $defaults, \@opts );
    is_deeply(
        \%{ $class . '::OPTIONS' },
        { password => 'hello', user => 2, verbose => 2, host => 3 },
        '...test default override'
    );

}

sub fixture : Test(setup) {
    my $self = shift;
    $self->{mock}->clear;

}

sub test_build_sql_cmdline : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'buildSqlCmdline' )
      || return 'buildSqlCmdline not implemented.';
    my $instance = $self->{instance};
    my $class    = $self->{class};
    no strict 'refs';
    local *buildSqlCmdline;
    *buildSqlCmdline = *{ $class . '::buildSqlCmdline' };
    %{ $class . '::OPTIONS' } = ( user => 'me' );    #setup this monster
    my $result = buildSqlCmdline();
    is( $result, ' -u me ', '...tests user option' );
    %{ $class . '::OPTIONS' } =
      ( user => 'me', host => '122.1', password => 'secret' )
      ;                                              #setup this monster

    $result = buildSqlCmdline();
    is( $result, ' -u me  -psecret  --host=122.1 ', '...tests all options' );
}

### XXX: DBI->table_info????
sub test_export_tables : Test(2) {
    return "Uses untestable backticks";
    my $self = shift;
    can_ok( $self->{class}, 'exportTables' )
      || return 'exportTables not implemented.';
    my $instance = $self->{instance};
    no strict 'refs';
    my $test_code = *{ $self->{class} . '::exportTables' }{CODE};

}

sub test_create_dB : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'createDB' ) || return 'createDB not implemented.';
    my $instance = $self->{instance};
    my $mock     = $self->{mock};
    $mock->set_always( 'getDatabaseHandle', $mock );
    $mock->set_true('do');
    my $test_code = \&{ $self->{class} . '::createDB' };
    $test_code->('dbname');
    my ( $method, $args ) = $mock->next_call;
    is( $method, 'getDatabaseHandle', '...should ask for dbh.' );
    ( $method, $args ) = $mock->next_call;
    is_deeply(
        [ $method, @$args ],
        [ 'do', $mock, 'create database dbname' ],
        '...and then sends SQL.'
    );

}

sub test_drop_dB : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'dropDB' ) || return 'dropDB not implemented.';
    my $instance = $self->{instance};
    my $mock     = $self->{mock};
    $mock->set_always( 'getDatabaseHandle', $mock );
    $mock->set_true('do');
    my $test_code = \&{ $self->{class} . '::dropDB' };
    $test_code->('dbname');
    my ( $method, $args ) = $mock->next_call;
    is( $method, 'getDatabaseHandle', '...should ask for dbh.' );
    ( $method, $args ) = $mock->next_call;
    is_deeply(
        [ $method, @$args ],
        [ 'do', $mock, 'drop database dbname' ],
        '...and then sends SQL.'
    );

}

sub test_add_tables_to_db : Test(6) {
    my $self = shift;
    can_ok( $self->{class}, 'addTablesToDB' )
      || return 'addTablesToDB not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::addTablesToDB' };
    my $tempdir   = File::Temp::tempdir( TMPDIR => 1, CLEANUP => 1 );
    my @files     = ( 'one.sql', 'two.sql', 'three.sql' );
    foreach (@files) {
        my $fh = IO::File->new( File::Spec->catfile( $tempdir, $_ ), 'w' );
        print $fh "$_";
        close $fh;
    }

    my %sub_args = ();
    {
        no strict 'refs';

        package Everything::Nodeball;
        use subs 'system';

        *{ $self->{class} . '::system' } =
          sub { $sub_args{ $_[0] } = 1 };
        use strict 'refs';
    }

    my @rv = $test_code->( 'test', $tempdir );
    is_deeply( { map { $_ => 1} @rv } ,{ map { $_ => 1} @files }, '...returns the processed files' );
    is (
        $sub_args{"mysql  -u  test<$tempdir/one.sql"},
        1,
        '...processing the sql files.'
    );
    is (
        $sub_args{"mysql  -u  test<$tempdir/two.sql"},
        1,
        '...processing the sql files.'
    );
    is (
        $sub_args{"mysql  -u  test<$tempdir/three.sql"},
        1,
        '...processing the sql files.'
    );

    @rv = $test_code->( 'test', $tempdir, ['three'] );
    is_deeply( \@rv, [ $files[2] ], '...with included files only.' );
}

sub test_get_tables_hashref : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'getTablesHashref' )
      || return 'getTablesHashref not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::getTablesHashref' };

    my $mock = $self->{mock};
    my @connect_args;
    $mock->fake_module( 'DBI',
        connect => sub { @connect_args = @_; return $mock } );
    $mock->set_always( prepare => $mock );
    $mock->set_true( 'execute', 'finish', 'disconnect' );
    $mock->set_series( 'fetchrow_arrayref', ['one'], ['two'], ['three'] );

    my $rv = $test_code->($mock);
    is_deeply(
        $rv,
        { one => 1, two => 1, three => 1 },
        '...gets a hashref of tables'
    );

}

sub test_get_columns : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'getColumns' )
      || return 'getColumns not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::getColumns' };

    my $mock = $self->{mock};
    my @connect_args;
    $mock->fake_module( 'DBI',
        connect => sub { @connect_args = @_; return $mock } );
    $mock->set_always( prepare => $mock );
    $mock->set_true( 'execute', 'finish', 'disconnect' );
    $mock->set_series(
        'fetchrow_hashref',
        { Field => 'one',   type => 'hello', perm => 'goodbye' },
        { Field => 'two',   type => 'hello', perm => 'goodbye' },
        { Field => 'three', type => 'hello', perm => 'goodbye' }
    );

    my $rv = $test_code->($mock);
    is_deeply(
        $rv,
        {
            one   => { Field => 'one',   type => 'hello', perm => 'goodbye' },
            two   => { Field => 'two',   type => 'hello', perm => 'goodbye' },
            three => { Field => 'three', type => 'hello', perm => 'goodbye' }
        },
        '...gets a hashref of tables'
    );

}

sub test_compare_all_tables : Test(7) {
    my $self = shift;
    can_ok( $self->{class}, 'compareAllTables' )
      || return 'compareAllTables not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::compareAllTables' };

    my @args;
    my @getColumns_returns = (
        {
            key1 => { key11 => 'value2' },
            key2 => { key22 => 'value2' }
        },
        {
            key1 => { key11 => 'value2' },
            key2 => { key22 => 'value2' }
        },
        {
            key3 => { key33 => 'value3' },
            key4 => { key44 => 'value4' }
        },
        {
            key3 => { key33 => 'value3' },
            key4 => { key44 => 'value4' }
        },
    );
    no strict 'refs';
    local *{ $self->{class} . '::addTablesToDB' };
    *{ $self->{class} . '::addTablesToDB' } =
      sub { my @c = @_; push @args, \@c };
    local *{ $self->{class} . '::getColumns' };
    *{ $self->{class} . '::getColumns' } =
      sub { my @c = @_; push @args, \@c; return shift @getColumns_returns };

    my $rv;
    use strict 'refs';
    {
        local *STDOUT;    # stop the noise!!
        $rv = $test_code->(
            { table1 => 1, table2 => 1 },
            { table1 => 1, table2 => 1, table3 => 1 },
            'dummydb', 'correctdb', 'random_dir'
        );
    }
    is_deeply(
        $args[0],
        [ 'table1', 'dummydb' ],
        '...gets dummydb.table1 cols.'
    );
    is_deeply(
        $args[1],
        [ 'table1', 'correctdb' ],
        '...gets correct.dbtable1 cols.'
    );
    is_deeply(
        $args[2],
        [ 'table2', 'dummydb' ],
        '...gets dummydb.table2 cols.'
    );
    is_deeply(
        $args[3],
        [ 'table2', 'correctdb' ],
        '...gets correct.dbtable2 cols.'
    );
    is_deeply(
        $args[4],
        [ 'correctdb', 'random_dir', ['table3'] ],
        '...checks and adds table3.'
    );
    is( $rv, 1, '...should return true.' );

}

sub test_check_named_tables : Test(11) {
    my $self = shift;
    can_ok( $self->{class}, 'checkNamedTables' )
      || return 'checkNamedTables not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::checkNamedTables' };
    my $mock      = $self->{mock};
    $mock->{dbname} = 'a db';
    my @args = ();
    no strict 'refs';
    local *{ $self->{class} . '::addTablesToDB' };
    *{ $self->{class} . '::addTablesToDB' } =
      sub { my @c = @_; push @args, \@c };
    local *{ $self->{class} . '::compareAllTables' };
    *{ $self->{class} . '::compareAllTables' } =
      sub { my @c = @_; push @args, \@c };
    local *{ $self->{class} . '::getTablesHashref' };
    *{ $self->{class} . '::getTablesHashref' } =
      sub { my @c = @_; push @args, \@c; return "$_[0]-hashrefreturn" };
    local *{ $self->{class} . '::initEverything' };
    *{ $self->{class} . '::initEverything' } = sub { 'initEverything' };
    local *{ $self->{class} . '::createDB' };
    *{ $self->{class} . '::createDB' } = sub { my @c = @_; push @args, \@c };
    local *{ $self->{class} . '::dropDB' };
    *{ $self->{class} . '::dropDB' } = sub { my @c = @_; push @args, \@c };

    use strict 'refs';
    my $rv = $test_code->( [qw/table1 table2/], 'a dir' );
    like( $args[0]->[0], qr/dummy\d+/, '...makes a new dummy db.' );

    is_deeply(
        [ @{ $args[1] }[ 1 .. 2 ] ],
        [ 'a dir', [qw/table1 table2/] ],
        '...adds tables to dummy db.'
    );
    is( $args[2]->[0], 'a db', '...gets db tables hash.' );
    like( $args[3]->[0], qr/dummy\d+/, '...gets dummy tables hash.' );

    is(
        $args[4]->[0],
        'a db-hashrefreturn',
        '...passes return from get tables hashref.'
    );
    like( $args[4]->[1], qr/dummy\d+-hashrefreturn/, '...again for dummydb.' );
    like( $args[4]->[2], qr/dummy\d+/, '...and the dummy db.' );
    is( $args[4]->[3], 'a db',  '...and the real db.' );
    is( $args[4]->[4], 'a dir', '...and the table directory.' );
    like( $args[5]->[0], qr/dummy\d+/, '...finally drops db.' );
}

sub test_check_tables : Test(11) {
    my $self = shift;
    can_ok( $self->{class}, 'checkTables' )
      || return 'checkTables not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::checkTables' };
    my $mock      = $self->{mock};
    $mock->{dbname} = 'a db';
    my @args = ();
    no strict 'refs';
    local *{ $self->{class} . '::addTablesToDB' };
    *{ $self->{class} . '::addTablesToDB' } =
      sub { my @c = @_; push @args, \@c };
    local *{ $self->{class} . '::compareAllTables' };
    *{ $self->{class} . '::compareAllTables' } =
      sub { my @c = @_; push @args, \@c };
    local *{ $self->{class} . '::getTablesHashref' };
    *{ $self->{class} . '::getTablesHashref' } =
      sub { my @c = @_; push @args, \@c; return "$_[0]-hashrefreturn" };
    local *{ $self->{class} . '::initEverything' };
    *{ $self->{class} . '::initEverything' } = sub { 'initEverything' };
    local *{ $self->{class} . '::createDB' };
    *{ $self->{class} . '::createDB' } = sub { my @c = @_; push @args, \@c };
    local *{ $self->{class} . '::dropDB' };
    *{ $self->{class} . '::dropDB' } = sub { my @c = @_; push @args, \@c };

    use strict 'refs';
    my $rv = $test_code->('a dir');
    like( $args[0]->[0], qr/dummy\d+/, '...makes a new dummy db.' );

    is_deeply( [ @{ $args[1] }[1] ], ['a dir'], '...adds tables to dummy db.' );
    is( $args[2]->[0], 'a db', '...gets db tables hash.' );
    like( $args[3]->[0], qr/dummy\d+/, '...gets dummy tables hash.' );

    is(
        $args[4]->[0],
        'a db-hashrefreturn',
        '...passes return from get tables hashref.'
    );
    like( $args[4]->[1], qr/dummy\d+-hashrefreturn/, '...again for dummydb.' );
    like( $args[4]->[2], qr/dummy\d+/, '...and the dummy db.' );
    is( $args[4]->[3], 'a db',  '...and the real db.' );
    is( $args[4]->[4], 'a dir', '...and the table directory.' );
    like( $args[5]->[0], qr/dummy\d+/, '...finally drops db.' );

}

sub test_create_dir : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'createDir' )
      || return 'createDir not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::createDir' };
    my $tempdir   = get_temp_dir();

    my $rv = $test_code->($tempdir);
    ok( -e $tempdir, '...creates directory.' );
    dies_ok { $test_code->($tempdir) } 'dies if directory already exists';
    rmdir $tempdir;
}

sub test_export_nodes : Test(5) {
    my $self = shift;
    can_ok( $self->{class}, 'exportNodes' )
      || return 'exportNodes not implemented.';
    my $instance = $self->{instance};
    my $mock     = $self->{mock};
    $mock->fake_module('Everything::XML::Node');
    $mock->fake_new('Everything::XML::Node');
    $mock->mock( toXML => sub { "some xml" } );
    my $test_code = \&{ $self->{class} . '::exportNodes' };
    my @args      = ();
    my @subs      = ();
    my $title     = 'a';
    no strict 'refs';

    local *{ $self->{class} . '::getNode' };
    *{ $self->{class} . '::getNode' } = sub {
        my @c = @_;
        push @args, \@c, push @subs, 'geNode';
        return { node_id => $_[0], title => $title++ };
    };

    local *{ $self->{class} . '::getId' };
    *{ $self->{class} . '::getId' } = sub { $_[0]->{node_id} };

    use strict 'refs';

    my $tempdir = get_temp_dir();
    my @rv    = $test_code->( [ 1, 2, 3 ], $tempdir );
    my $dir   = IO::Dir->new($tempdir);
    my @files = $dir->read;

    my %exists = map { $_ => 1 } grep { !/^\./ } @files;
    is_deeply(
        \%exists,
        { 'd.xml' => 1, 'e.xml' => 1, 'f.xml' => 1 },
        '...creates all files.'
    );
    foreach ( keys %exists ) {
        my $path = File::Spec->catfile( $tempdir, $_ );
        my $fh = IO::File->new($path);
        local $/;
        my $content = <$fh>;
        is( $content, 'some xml', '...check file content.' );
        $fh->close;
        unlink $path;
    }
    rmdir $tempdir;
}

sub test_print_settings : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'printSettings' )
      || return 'printSettings not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::printSettings' };

    {
        my $printed;
        eval { require 5.008 };
        return "Only runs IO tests on 5.8 or greater" if $@;
        local *STDOUT;
        open *STDOUT, '>', \$printed;
        $test_code->( { a => 1, b => 2 } );
        is( $printed, "a :\t1\nb :\t2\n\n", '...prints vars.' );
    }
}

sub test_create_nodeball : Test(2) {
    return "Uses untestable backticks";
    my $self = shift;
    can_ok( $self->{class}, 'createNodeball' )
      || return 'createNodeball not implemented.';
    my $instance = $self->{instance};
    my $mock     = $self->{mock};
    $mock->{title} = 'a nodeball';
    my $test_code = \&{ $self->{class} . '::createNodeball' };

    my $tmpdir = get_temp_dir();
    no strict 'refs';
    local *{ $self->{class} . '::getcwd' };
    *{ $self->{class} . '::getcwd' } = sub { File::Spec->tmpdir };
    use strict 'refs';

    $mock->set_always( 'getVars', { a => 1, b => 2 } );

    mkdir $tmpdir;
    my $printed;
    my $in = 'y';

    {
        local *STDOUT;    # stop the noise;
        $test_code->( $tmpdir, $mock );
    }
    ok(
        -e File::Spec->tmpdir . "/a_nodeball.nbz",
        '..nodeball file should be created.'
    );
    $self->{nodeball_file} = File::Spec->tmpdir . "/a_nodeball.nbz";
    rmdir $tmpdir;
}

sub test_expand_nodeball : Test(2) {
    return "Uses untestable backticks";
    my $self = shift;
    can_ok( $self->{class}, 'expandNodeball' )
      || return 'expandNodeball not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::expandNodeball' };
    my $rv        = $test_code->( $self->{nodeball_file} );
    like( $rv, qr{/tmp/everything\d+}, '...returns the directory.' );
    rmdir $rv;
}

## gets all nodeballs for a nodebase
sub test_build_nodeball_members : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'buildNodeballMembers' )
      || return 'buildNodeballMembers not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::buildNodeballMembers' };

    no strict 'refs';

    local *{ $self->{class} . '::getNodeWhere' };
    *{ $self->{class} . '::getNodeWhere' } = sub {
        [
            { title => 'nodeball 1', node_id => 1, group => [qw/a b/] },
            { title => 'nodeball 2', node_id => 2, group => [qw/c d/] }
        ];
    };

    local *{ $self->{class} . '::getId' };
    *{ $self->{class} . '::getId' } = sub { return $_[0]->{node_id} };

    local *{ $self->{class} . '::getType' };
    *{ $self->{class} . '::getType' } = sub { { title => 'a type' } };

    my $rv = $test_code->( { node_id => 2 } );
    is_deeply( $rv, { a => 1, b => 1 }, '...hash of nodes and balls.' );
}

sub test_abs_path : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'absPath' ) || return 'absPath not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::absPath' };
    my $rv        = $test_code->('~/here');
    is( $rv, $ENV{HOME} . '/here', '..gets absolute unix path.' );
}

sub test_clean_up_dir : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'cleanUpDir' )
      || return 'cleanUpDir not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::cleanUpDir' };
    my $tempdir   = get_temp_dir();
    $test_code->($tempdir);
    ok( !-e $tempdir, '..temp directory shouldn\'t exist.' );
}

# checks if a node (which is in a ball) references another node (which
# isn't in the ball provided it isn't in the core group.
sub test_check_deps : Test(4) {
    my $self = shift;
    can_ok( $self->{class}, 'checkDeps' )
      || return 'checkDeps not implemented.';
    my $instance = $self->{instance};
    my $mock     = $self->{mock};
    my $id       = 10000;
    $mock->set_true('getRef');
    $mock->mock( getId => sub { $_[1]->{node_id} } );
    $mock->{special_key} = 8;
    $mock->mock(
        getNode => sub {
            $mock->{node_id} = $id++;
            $mock->{title} = join( '', @_ );
            return $mock;
        }
    );

    ## NB: undocumented feature: code expects things that refer to
    ## other nodes to have an underscore.
    $mock->mock(
        getNodeKeys => sub {
            return {
                title   => $mock->{title},
                node_id => $mock->{node_id},
                one     => 'two'
              }
              unless $_[0]->{node_id} eq 10005;
            return { special_key => 8 };
        }
    );
    my $test_code = \&{ $self->{class} . '::checkDeps' };
    {
        my $printed;
        eval { require 5.008 };
        return "Only runs IO tests on 5.8 or greater" if $@;
        local *STDOUT;
        open *STDOUT, '>', \$printed;
        $test_code->( { node_id => 999, group => [ 1, 2, 3 ] } );
        like( $printed, qr/referenced by/, '...checks for nodes not in ball.' );

        # test inCOre
        $mock->mock(
            getNode => sub {
                $mock->{node_id} = 8;
                $mock->{title} = join( '', @_ );
                return $mock;
            }
        );
        $printed = '';
        $test_code->( { node_id => 999, group => [ 1, 2, 3 ] } );
        is( $printed, '', '...reports nothing if node in core.' );

        $id = 10000;
        $mock->{special_key} = -1;
        $mock->mock(
            getNode => sub {
                $mock->{node_id} = $id++;
                $mock->{title} = join( '', @_ );
                return $mock;
            }
        );

        $mock->mock(
            getNodeKeys => sub {
                return {
                    title       => $mock->{title},
                    node_id     => $mock->{node_id},
                    one         => 'two',
                    special_key => -1
                };
            }
        );

        $test_code->( { node_id => 999, group => [ 1, 2, 3 ] } );
        is( $printed, '', '...reports nothing if ref is -1.' );

    }

}

sub test_install_nodeball : Test(8) {
    my $self = shift;
    can_ok( $self->{class}, 'installNodeball' )
      || return 'installNodeball not implemented.';
    my $instance = $self->{instance};

    my $test_code = \&{ $self->{class} . '::installNodeball' };

    my $mock    = $self->{mock};
    my $tempdir = get_temp_dir();
    mkdir $tempdir;
    my $tables_dir = "$tempdir/tables";
    mkdir $tables_dir;
    foreach (qw/one two three/) {
        my $fh = IO::File->new( "$tables_dir/$_.sql", 'w' );
        print $fh 'some sql $_';
        close $fh;
    }
    mkdir "$tempdir/nodes";
    my $typesdir = "$tempdir/nodes/nodetype";
    mkdir $typesdir;
    foreach (qw/firsttype secondtype/) {
        my $fh = IO::File->new( "$typesdir/$_.xml", 'w' )
          || die "Can't open file, $!";
        print $fh 'some xml $_';
        close $fh;
    }
    foreach (qw/firstnode secondnode/) {
        my $fh = IO::File->new( "$tempdir/$_.xml", 'w' );
        print $fh 'some xml $_';
        close $fh;
    }

    my %xmlfile2node_args = ();
    no strict 'refs';
    local *{ $self->{class} . '::getTablesHashref' };
    *{ $self->{class} . '::getTablesHashref' } = sub { { 'three' => 1 } };

    local *{ $self->{class} . '::checkNamedTables' };
    *{ $self->{class} . '::checkNamedTables' } = sub { 0 };

    local *{ $self->{class} . '::xmlfile2node' };
    *{ $self->{class} . '::xmlfile2node' } =
      sub { $xmlfile2node_args{ $_[0] } = 1 };

    local *{ $self->{class} . '::fixNodes' };
    *{ $self->{class} . '::fixNodes' } = sub { 1 };

    local *{ $self->{class} . '::installModules' };
    *{ $self->{class} . '::installModules' } = sub { 1 };

    local *{ $self->{class} . '::buildSqlCmdline' };
    *{ $self->{class} . '::buildSqlCmdline' } = sub { '' };

    use strict 'refs';

    $mock->{dbname} = 'fictionaldb';
    $mock->{cache}  = $mock;
    $mock->set_true(qw/flushCache rebuildNodetypeModules/);

    my %system_arg = ();

    {

        package Everything::Nodeball;
        no warnings 'redefine';
        use subs 'system';
        *system = sub { $system_arg{$_[0]} = 1 };
        local *STDOUT;    #stop this being so noisy.
        $test_code->($tempdir);
    }

    is(
       $system_arg{"mysql fictionaldb < $tables_dir/one.sql"},
       1,
       '...check sql being processed.'
    );
    is(
       $system_arg{"mysql fictionaldb < $tables_dir/two.sql"},
       1,
        '...check sql being processed.'
    );
    is( scalar( keys %system_arg ), 2, '...but misses already included table.' );

    is( $xmlfile2node_args{"$typesdir/firsttype.xml"}, 1,
        '...first type file.' );
    is( $xmlfile2node_args{"$typesdir/secondtype.xml"}, 1,
        '...second type file.' );
    is( $xmlfile2node_args{"$tempdir/firstnode.xml"}, 1,
        '...first node file.' );
    is( $xmlfile2node_args{"$tempdir/secondnode.xml"}, 1,
        '...second node file.' );
    rmtree $tempdir;
}

sub test_install_modules : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'installModules' )
      || return 'installModules not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::installModules' };

    my $mock    = $self->{mock};
    my $tempdir = get_temp_dir();
    mkdir $tempdir;
    mkdir "$tempdir/Everything";
    foreach (qw/one two/) {
        my $fh = IO::File->new( "$tempdir/Everything/$_.pm", 'w' )
          || die "Can't create $tempdir/Everything, $!";
        print $fh 'some perl $_';
        close $fh;
    }

    my %copy_args;
    no strict 'refs';
    local *{ $self->{class} . '::copy' };
    *{ $self->{class} . '::copy' } = sub { $copy_args{$_[0]} = $_[1] };

    local *{ $self->{class} . '::getPMDir' };
    *{ $self->{class} . '::getPMDir' } = sub { 'pm_dir' };

    use strict 'refs';
    {
        local *STDOUT;    # stop the noise;
        $test_code->($tempdir);
    }
    is (
        $copy_args{"$tempdir/Everything/one.pm"},
	'pm_dir/Everything/one.pm',
        '..copy first test file.'
    );
    is (
        $copy_args{"$tempdir/Everything/two.pm"},
	'pm_dir/Everything/two.pm',
        '..copy second test file.'
    );
}

sub test_get_pmdir : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'getPMDir' ) || return 'getPMDir not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::getPMDir' };

    my @results;

    my $tempdir = get_temp_dir();
    mkdir $tempdir;
    mkdir "$tempdir/Everything";

    {
        local *INC;
        @INC = qw/one two three/;
        push @results, $test_code->();
        @INC = ( 'one', "$tempdir" );
        push @results, $test_code->();
    }

    is( $results[0], undef, '..returns undef if cannot find Everything dir.' );
    is( $results[1], $tempdir, '..otherwise returns path to Everything dir.' );

    rmtree $tempdir;
}

## this doesn't so much handle conflicts, as report to the user
## whether there are any conflicts and then asks the user what she/he
## wishes to do.
##
## New conflicting nodes that can be workspaced are workspaced.  Ones
## that aren't, the user is asked.

sub test_handle_conflicts : Test(13) {
    my $self = shift;
    can_ok( $self->{class}, 'handleConflicts' )
      || return 'handleConflicts not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::handleConflicts' };
    my $mock      = $self->{mock};

    $mock->set_always( getNode             => $mock );
    $mock->set_always( existingNodeMatches => $mock );
    $mock->set_always( -getVars => { version => 111 } );
    $mock->set_true( 'updateFromImport', 'joinWorkspace', '-insert' );
    $mock->set_series( -canWorkspace => 0, 1, 1 );

    $mock->{title} = "node title";
    $mock->{type}->{title} = 'node type';

    my $confirmyn_args;
    no strict 'refs';
    local *{ $self->{class} . '::confirmYN' };
    *{ $self->{class} . '::confirmYN' } = sub { $confirmyn_args = $_[0] };
    use strict 'refs';

    my $printed;

    {
        eval { require 5.008 };
        return "Only runs IO tests on 5.8 or greater" if $@;
        local *STDOUT;
        open *STDOUT, '>', \$printed;
        $test_code->( [ $mock, $mock, $mock ], $mock );
    }

    my ( $method, $args ) = $mock->next_call;
    is( $method, 'existingNodeMatches', '...checks for existing node.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'updateFromImport', '...updates from import.' );
    is(
        $confirmyn_args,
"node title (node type) has been modified, seems to conflict with the new nodeball, and cannot be workspaced.\nDo you want me to update it anyway? (N/y)\n",
        '...requests user for input.'
    );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'getNode', '...gets root user.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'getNode', '...creates a new node ball.' );
    is(
        join( ' ', @$args ),
        "$mock node title-111 changes workspace create",
        '...setting the nodeball version.'
    );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'joinWorkspace', '...joins workspace.' );

    ( $method, $args ) = $mock->next_call;
    is( $method, 'existingNodeMatches', '...calls existing node matches.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'updateFromImport', '...updates from import.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'existingNodeMatches', '...calls existing node matches.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'updateFromImport', '...updates from import.' );
    is(
        $printed,
"The following nodes may have conflicts:\n\tnode title (node type)\n\tnode title (node type)\n\nThe new versions have been put in workspace \"node title\"\nJoin that workspace as the root user to test and commit or discard the changes\n",
        '..and reports that nodes have been workspaced.'
    );
}

sub test_update_nodeball : Test(10) {
    my $self = shift;
    can_ok( $self->{class}, 'updateNodeball' )
      || return 'updateNodeball not implemented.';
    my $instance = $self->{instance};

    my $test_code = \&{ $self->{class} . '::updateNodeball' };

    my $mock = $self->{mock};
    $mock->{group} = [222];
    $mock->set_always( -existingNodeMatches => $mock );
    $mock->mock( -getId => sub { $_[0]->{node_id} } );
    $mock->set_always( -getNode => $mock );
    $mock->set_series( conflictsWith => 0, 1 );

    my $tempdir = get_temp_dir();
    mkdir $tempdir;
    my $tables_dir = "$tempdir/tables";
    mkdir $tables_dir;
    foreach (qw/one two three/) {
        my $fh = IO::File->new( "$tables_dir/$_.sql", 'w' );
        print $fh 'some sql $_';
        close $fh;
    }
    mkdir "$tempdir/nodes";
    my $typesdir = "$tempdir/nodes/nodetype";
    mkdir $typesdir;
    foreach (qw/firsttype secondtype/) {
        my $fh = IO::File->new( "$typesdir/$_.xml", 'w' )
          || die "Can't open file, $!";
        print $fh 'some xml $_';
        close $fh;
    }
    my $nodesdir = "$tempdir/nodes";

    foreach (qw/firstnode secondnode/) {
        my $fh = IO::File->new( "$nodesdir/$_.xml", 'w' );
        print $fh 'some xml $_';
        close $fh;
    }

    my %xmlfile2node_args = ();
    my $confirmyn_args;
    no strict 'refs';

    local *{ $self->{class} . '::confirmYN' };
    *{ $self->{class} . '::confirmYN' } = sub { $confirmyn_args = $_[0] };

    local *{ $self->{class} . '::getTablesHashref' };
    *{ $self->{class} . '::getTablesHashref' } = sub { { 'three' => 1 } };

    local *{ $self->{class} . '::checkNamedTables' };
    *{ $self->{class} . '::checkNamedTables' } = sub { 0 };

    local *{ $self->{class} . '::buildNodeballMembers' };
    *{ $self->{class} . '::buildNodeballMembers' } = sub { { one => 2 } };

    local *{ $self->{class} . '::xmlfile2node' };

    my @xmlfile_returns = ( [111], [222] );
    *{ $self->{class} . '::xmlfile2node' } =
      sub { $xmlfile2node_args{$_[0]} = 1; return shift @xmlfile_returns };

    local *{ $self->{class} . '::checkTables' };
    *{ $self->{class} . '::checkTables' } = sub { 1 };

    local *{ $self->{class} . '::fixNodes' };
    *{ $self->{class} . '::fixNodes' } = sub { 1 };

    local *{ $self->{class} . '::installModules' };
    *{ $self->{class} . '::installModules' } = sub { 1 };

    no warnings 'redefine';
    local *{ $self->{class} . '::handleConflict' };
    *{ $self->{class} . '::handleConflicts' } = sub { 1 };

    local *{ $self->{class} . '::buildSqlCmdline' };
    *{ $self->{class} . '::buildSqlCmdline' } = sub { '' };

    use strict 'refs';

    $mock->{dbname} = 'fictionaldb';
    $mock->{cache}  = $mock;
    $mock->set_true(qw/flushCache rebuildNodetypeModules/);
    my $printed;

    {
        eval { require 5.008 };
        return "Only runs IO tests on 5.8 or greater" if $@;
        local *STDOUT;
        open *STDOUT, '>', \$printed;
        $test_code->( $mock, $mock, $tempdir );
    }

    is( $xmlfile2node_args{"$typesdir/firsttype.xml"}, 1,
        '...first type file.' );
    is( $xmlfile2node_args{"$typesdir/secondtype.xml"}, 1,
        '...second type file.' );
    is(
        $xmlfile2node_args{"$tempdir/nodes/firstnode.xml"}, 1,
        '...first node file.'
    );
    is(
        $xmlfile2node_args{"$tempdir/nodes/secondnode.xml"}, 1,
        '...second node file.'
    );

    my ( $method, $args ) = $mock->next_call;
    is( $method, 'conflictsWith', '...calls conflicts with.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'updateFromImport', '...then updates node from import.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'conflictsWith', '...checks conflicts again.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'updateFromImport', '...then updates node from import.' );

    is( $printed, "node title updated.\n", '...prints info.' );
    rmtree $tempdir;

}

sub test_remove_nodeball : Test(8) {

    no warnings 'void';    # get this warning localisaing STDIN

    my $self = shift;
    can_ok( $self->{class}, 'removeNodeball' )
      || return 'removeNodeball not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::removeNodeball' };

    my $mock = $self->{mock};
    $mock->set_always( -getId        => 999 );
    $mock->set_always( getNode       => $mock );
    $mock->set_always( -getType      => $mock );
    $mock->set_always( -getNodeWhere => [ $mock, $mock, $mock ] );
    $mock->set_always( -getVars => { version => "1.1" } );
    $mock->set_series( -inGroup => 0, 1, 1 );
    $mock->set_true('nuke');

    dies_ok { $test_code->($mock) },
      '...dies if nodeball is "in" another nodeball.';
    $mock->set_false('-inGroup');
    $mock->{group} = [ 1, 2 ];
    my $printed;
    my $in = 'y';
    {
        eval { require 5.008 };
        return "Only runs IO tests on 5.8 or greater" if $@;
        local *STDOUT;
        local *STDIN;
        open *STDOUT, '>', \$printed;
        open *STDIN,  '<', \$in;
        $test_code->($mock);
    }
    like( $printed, qr/Are you sure you want to remove/, '...asks question.' );
    my ( $method, $args ) = $mock->next_call(3);
    is( $method, 'getNode', '...gets nodes in ball.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'nuke', '...then nukes it.' );
    ( $method, $args ) = $mock->next_call();
    is( $method, 'getNode', '...gets nodes in ball.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'nuke', '...then nukes it.' );
    ( $method, $args ) = $mock->next_call;
    is( $method, 'nuke', '...then nukes ball.' );
}

sub test_confirm_yn : Test(4) {
    my $self = shift;
    can_ok( $self->{class}, 'confirmYN' )
      || return 'confirmYN not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::confirmYN' };

    my $printed;
    my $in = 'N';
    my $rv;
    {
        eval { require 5.008 };
        return "Only runs IO tests on 5.8 or greater" if $@;
        local *STDOUT;
        local *STDIN;
        open *STDOUT, '>', \$printed;
        open *STDIN,  '<', \$in;
        $rv = $test_code->('hello');
    }
    is( $printed, 'hello (N/y)', '...asks question.' );
    is( $rv,      0,             '...returns untrue if answer "N".' );

    $in = 'y';
    {
        local *STDOUT;
        local *STDIN;
        open *STDIN, '<', \$in;
        $rv = $test_code->('hello');
    }
    is( $rv, 1, '...returns true if answer "y".' );
}

sub get_temp_dir {
    return File::Spec->catfile( File::Spec->tmpdir, $$ . '_' . time );

}

1;
