package Everything::Storage::Test::Nodeball;

use base 'Everything::Test::Abstract';
use Test::More;
use File::Spec;
use Test::Exception;
use Test::MockObject;
use File::Temp;
use File::Path;
use File::Find;
#use Archive::Tar;
use IO::File;
use SQL::Statement;
use Cwd;
use strict;
use warnings;

sub startup : Test(+1) {

    ### use-ing Archive::Tar causes a seg fault.  Bug in perl 5.10??
    require 'Archive/Tar.pm'; 
    my $self = shift;
    $self->SUPER::startup;
    my $instance = $self->{class}->new;
    my ( $test_nodeball_d, $test_nodeball ) = $self->make_test_nodeball;
    $self->{test_nodeball_d} = $test_nodeball_d;
    $self->{test_nodeball}   = $test_nodeball;

    isa_ok( $instance, $self->{class} );
    $self->{instance} = $instance;
}

sub make_test_nodeball {
    my ($self) = @_;

    my $dir = get_temp_dir();
    
    mkdir $dir;

    chdir $dir;

    my @files = ();
    mkdir "tables";
    push @files, 'tables';
    mkdir "nodes";
    push @files, 'nodes';
    mkdir "nodes/nodetype";
    push @files, 'nodes/nodetype';
    local *FH;
    open FH, ">", "nodes/anode.xml" || die "Can't open file, $!";
    print FH "node xml\n";
    close FH;
    push @files, 'nodes/anode.xml';
    open FH, ">", "nodes/bnode.xml" || die "Can't open file, $!";
    print FH "some node xml\n";
    close FH;
    push @files, 'nodes/bnode.xml';
    open FH, ">", "nodes/nodetype/typeone.xml" || die "Can't open file, $!";
    print FH "some xml\n";
    close FH;
    push @files, 'nodes/nodetype/typeone.xml';
    open FH, ">", "nodes/nodetype/typetwo.xml" || die "Can't open file, $!";
    print FH "some xml\n";
    close FH;
    push @files, 'nodes/nodetype/typetwo.xml';

    my ( $fh, $fn ) = File::Temp::tempfile( SUFFIX => '.nbz' );
    $fh->close;

    my $tar = Archive::Tar->create_archive( $fn, 1, @files );

    return ( $dir, $fn );
}

sub fixture : Test(setup) {
    my $self     = shift;
    my $instance = $self->{class}->new;
    $self->{instance} = $instance;
    my $mock = Test::MockObject->new;
    $self->{mock} = $mock;

}

sub test_create_dir : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'createDir' )
      || return 'createDir not implemented.';
    my $instance = $self->{instance};
    my $tempdir  = get_temp_dir();

    my $rv = $instance->createDir($tempdir);
    ok( -e $tempdir, '...creates directory.' );
    dies_ok { $instance->createDir($tempdir) }
      '...dies if directory already exists';
    rmdir $tempdir;
}

sub test_nodeball_vars : Test(5) {
    my $self = shift;
    can_ok( $self->{class}, 'nodeball_vars' ) || return "not implemented.";

    my $instance = $self->{instance};

    my $mock = Test::MockObject->new;
    my $fh = File::Temp->new( UNLINK => 1 );
    local *IO::File::new;
    *IO::File::new = sub { $fh };
    $mock->set_always( readline => 'some xml' );
    my @readTag_r = qw/version author description title/;
    my @readTag_a;
    no strict 'refs';
    local *{ $self->{class} . '::readTag' };
    *{ $self->{class} . '::readTag' } =
      sub { my @c = @_; push @readTag_a, \@c; return shift @readTag_r; };
    use strict 'refs';

    my $rv = $instance->nodeball_vars('nothing');
    is_deeply(
        $rv,
        {
            author      => 'author',
            version     => 'version',
            description => 'description',
            title       => 'title'
        },
        '...returns a hash ref of attributes.'
    );

    # test exception throwing.
    my $dir = "/some/path";
    local *IO::File::new;
    *IO::File::new =  sub { };
    throws_ok { $instance->nodeball_vars($dir) }
      'Everything::Exception::CorruptNodeball',
      "...if can't open ME file throws an error";
    is( $@->{nodeball_path}, "$dir", '...passing the path to the nodeball.' );
    is( $@->{file_path}, "$dir/ME", '...and the path to the ME file.' );
}

sub test_expand_nodeball : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'expand_nodeball' )
      || return 'expand_nodeball not implemented.';
    my $instance = $self->{instance};
    my $rv       = $instance->expand_nodeball( $self->{test_nodeball} );
    like( $rv, qr{/tmp/everything\w{5}}, '...returns the directory.' );
    rmdir $rv;
}

sub test_new_params : Test(9) {
    my $self = shift;

    my $instance;
    my $test_nodeball_d = $self->{test_nodeball_d};
    my $test_nodeball   = $self->{test_nodeball};

    ok( $instance = $self->{class}->new( nodeball => $test_nodeball_d ),
        '...we instantiate with a nodeball dir.' );
    is( $instance->get_nodeball_dir, $test_nodeball_d, '...sets the dir.' );
    is( $instance->get_nodeball, $test_nodeball_d,
        '...ditto if we get nodeball.' );

    ok( $instance = $self->{class}->new( nodeball => $test_nodeball ),
        '...instatiate with a nodeball file' );
    is( $instance->get_file, $test_nodeball,
        '...but if we pass a file returns the file' );
    is( $instance->get_nodeball, $test_nodeball,
        '...also if we get nodeball.' );
    my $mock = Test::MockObject->new;
    my $args;
    $mock->fake_module( 'Everything::NodeBase', 'new',
        sub { $args = join( ' ', @_ ); return $mock } );

    my @db_args = qw/fakedb fakeuser fakepass fakehost Pg/;
    ok(
        $instance = $self->{class}->new(
            db_name     => $db_args[0],
            db_user     => $db_args[1],
            db_password => $db_args[2],
            db_type     => $db_args[4],
            db_host     => $db_args[3]
        ),
        '...args to instantiate a nodebase.'
    );
    is(
        $args,
        join( ' ',
            'Everything::NodeBase', join( ':', @db_args[ 0 .. 3 ] ),
            1,                      $db_args[4] ),
        '...nodebase is instantiated with the correct arguments.'
    );
    is( $instance->get_nodebase, $mock, '...the nodebase attribute is set.' );

}

## gets all nodeballs for a nodebase
sub test_build_nodeball_members : Test(2) {
    my $self = shift;
    can_ok( $self->{class}, 'buildNodeballMembers' )
      || return 'buildNodeballMembers not implemented.';
    my $instance  = $self->{instance};
    my $test_code = \&{ $self->{class} . '::buildNodeballMembers' };

    my $mock  = Test::MockObject->new;
    my $node1 = Test::MockObject->new;
    my $node2 = Test::MockObject->new;
    $node1->{node_id} = 1;
    $node1->{group}   = [qw/a b/];
    $node2->{node_id} = 2;
    $node2->{group}   = [qw/c d/];

    $mock->mock(
        getNodeWhere => sub {
            [ $node1, $node2 ];
        }
    );
    $mock->set_true('getType');
    $mock->set_always( getId => 2 );
    $node1->mock( getId => sub { $_[0]->{node_id} } );
    $node2->mock( getId => sub { $_[0]->{node_id} } );

    my $rv = $test_code->( $mock, $mock );
    is_deeply( $rv, { a => 1, b => 1 }, '...hash of nodes and balls.' );
}

sub test_build_sql_cmdline : Test(3) {
    my $self = shift;
    can_ok( $self->{class}, 'buildSqlCmdline' )
      || return 'buildSqlCmdline not implemented.';
    my $instance = $self->{instance};
    my $class    = $self->{class};
    no strict 'refs';
    $instance->set_db_user('me');

    my $result = $instance->buildSqlCmdline();
    is( $result, ' -u me ', '...tests user option' );
    $instance->set_db_host('122.1');
    $instance->set_db_password('secret');

    $result = $instance->buildSqlCmdline();
    is( $result, ' -u me  -psecret  --host=122.1 ', '...tests all options' );
}

sub test_install_xml_nodes : Test( 3 ) {

    my $self = shift;
    can_ok( $self->{class}, 'install_xml_nodes' )
      || return 'install_nodeball not implemented.';
    my $instance = $self->{instance};

    my $dir = $self->{test_nodeball_d};
    $instance->set_nodeball_dir($dir);

    my @xml2node_args = ();
    no strict 'refs';
    local *{ $self->{class} . '::xml2node' };
    *{ $self->{class} . '::xml2node' } = sub { push @xml2node_args, $_[0] };
    use strict 'refs';

    $instance->install_xml_nodes();

    my %files = map { $_ => 1 } @xml2node_args;
    my %expected_files = map { $_ => 1 } (
        'some xml
', 'some node xml
', 'node xml
'
    );

    is_deeply( \%files, \%expected_files,
        '...processes all xml files under node/.' );

    @xml2node_args = ();

    $instance->install_xml_nodes(
        sub { return 1 unless $_[0]->get_raw_xml =~ /node/; return; } );

    %files = map { $_ => 1 } @xml2node_args;
    %expected_files = map { $_ => 1 } (
        'some xml
'
    );

    is_deeply( \%files, \%expected_files,
        '...and excludes specifically excluded nodes.' );

}

sub test_install_nodeball : Test( 5 ) {
    my $self = shift;
    can_ok( $self->{class}, 'install_nodeball' )
      || return 'install_nodeball not implemented.';
    my $instance = $self->{instance};

    my $mock = Test::MockObject->new;
    $instance->set_nodebase($mock);
    $mock->set_false('getNode');
    $mock->{storage} = $mock;

    my $tempdir = get_temp_dir();
    mkdir $tempdir;

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
        my $fh = IO::File->new( "$tempdir/nodes/$_.xml", 'w' );
        print $fh 'some xml $_';
        close $fh;
    }

    no strict 'refs';
    local *{ $self->{class} . '::getTablesHashref' };
    *{ $self->{class} . '::getTablesHashref' } = sub { { 'three' => 1 } };

    my @xmlfile2node_args = ();
    local *{ $self->{class} . '::xml2node' };
    *{ $self->{class} . '::xml2node' } = sub { push @xmlfile2node_args, $_[0] };

    local *{ $self->{class} . '::insert_sql_tables' };
    *{ $self->{class} . '::insert_sql_tables' } = sub { 1 };

    local *{ $self->{class} . '::nodeball_vars' };
    *{ $self->{class} . '::nodeball_vars' } =
      sub { { 'title' => 'fake nodeball' } };

    local *{ $self->{class} . '::fixNodes' };
    *{ $self->{class} . '::fixNodes' } = sub { 1 };

    local *{ $self->{class} . '::installModules' };
    *{ $self->{class} . '::installModules' } = sub { 1 };

    local *{ $self->{class} . '::buildSqlCmdline' };
    *{ $self->{class} . '::buildSqlCmdline' } = sub { '' };

    local *Everything::XML::Node::new;
    *Everything::XML::Node::new = sub { $mock };

    use strict 'refs';

    $mock->set_series( 'get_nodetype', 'nodetype', 'nodetype', 'blah', 'blah' );
    $mock->set_series( 'get_raw_xml',  'a',        'b',        'c',    'd' );
    $mock->set_always( 'parse_xml', 'blah blah' );

    $mock->{dbname} = 'fictionaldb';
    $mock->{cache}  = $mock;
    $mock->set_true(qw/flushCache rebuildNodetypeModules/);

    $instance->set_nodeball_dir($tempdir);

    $instance->install_nodeball();

    is( $xmlfile2node_args[0], "a", '...first type file.' );
    is( $xmlfile2node_args[1], "b", '...second type file.' );
    is( $xmlfile2node_args[2], "c", '...first node file.' );
    is( $xmlfile2node_args[3], "d", '...second node file.' );
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
    *{ $self->{class} . '::copy' } = sub {  $copy_args{ $_[0] } = $_[1] };

    local *{ $self->{class} . '::getPMDir' };
    *{ $self->{class} . '::getPMDir' } = sub { 'pm_dir' };

    use strict 'refs';

    $test_code->($tempdir);

    is (
        $copy_args{ "$tempdir/Everything/one.pm" },
        'pm_dir/Everything/one.pm',
        '..copy first test file.'
    );
    is (
        $copy_args{ "$tempdir/Everything/two.pm" },
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

sub test_set_get_nodeball : Test(5) {
    my $self = shift;
    can_ok( $self->{class}, 'set_nodeball' ) || return "not implemented.";

    my $instance = $self->{instance};

    my $test_nodeball_d = $self->{test_nodeball_d};
    my $test_nodeball   = $self->{test_nodeball};

    $instance->set_nodeball($test_nodeball_d);
    is( $instance->get_nodeball_dir, $test_nodeball_d,
        '...if we pass a dir, sets the dir.' );
    is( $instance->get_nodeball, $test_nodeball_d,
        '...ditto if we get nodeball.' );

    $instance->set_nodeball($test_nodeball);
    is( $instance->get_file, $test_nodeball,
        '...but if we pass a file returns the file' );
    is( $instance->get_nodeball, $test_nodeball,
        '...also if we get nodeball.' );
}

my $count = 0;

sub get_temp_dir {
    return File::Spec->catfile( File::Spec->tmpdir,
        $$ . '_' . time . '_' . $count++ );

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

sub test_install_xml_node : Test(1) {
    my $self = shift;

    my $instance = $self->{instance};
    my $mock = Test::MockObject->new;
    $mock->set_always( get_raw_xml => 'some xml' );

    my @xml2node_args = ();
    no strict 'refs';
    local *{ $self->{class} . '::xml2node' };
    *{ $self->{class} . '::xml2node' } = sub { push @xml2node_args, $_[0] };
    use strict 'refs';

    $instance->install_xml_node( $mock );
    is_deeply( \@xml2node_args, [ 'some xml' ], '...calls xml2node with with xml.');


}

sub test_build_new_nodes : Test(2) {
    my $self = shift;
    my $instance = $self->{instance};

    my $mock = Test::MockObject->new;
    $mock->set_always( get_raw_xml => 'some xml' );

    my @xmlnodes = ( $mock, $mock );
    no strict 'refs';
    local *{ $self->{class} . '::make_node_iterator' };
     *{ $self->{class} . '::make_node_iterator' } = sub { sub { shift @xmlnodes } };
    my @xml2node_args = ();
    local *{ $self->{class} . '::xml2node' };
    *{ $self->{class} . '::xml2node' } = sub { push @xml2node_args, $_[0], $_[1]; return [ $mock ] };
    use strict 'refs';

    my @nodes = $instance->build_new_nodes;

    is_deeply ( \@nodes, [ $mock, $mock ], '...returns a list of node objects.');
    is_deeply ( \@xml2node_args, ['some xml', 'nofinal', 'some xml', 'nofinal' ], '...calls  xml2node with nofinal argument.');
}

sub test_update_node_to_nodebase :Test(9) {
    my $self = shift;
    my $instance = $self->{instance};
    my $node = Test::MockObject->new;
    my $oldnode = Test::MockObject->new;

    $oldnode->set_true('updateFromImport');
    $oldnode->set_series(conflictsWith => 1, 0);

    $node->set_series( existingNodeMatches => $oldnode, undef );
    $node->set_true('insert');

    $instance->update_node_to_nodebase( $node );

    my ( $method, $args ) = $node->next_call;

    is( $method, 'existingNodeMatches', '....checks to see whether a node is matching.');

    ( $method, $args ) = $oldnode->next_call;
    is($method, 'conflictsWith', '...tries to see whether an importing node is conflicting.');
    is($args->[1], $node, '...with the new node as an argument.');

   ( $method, $args ) = $oldnode->next_call;
    is($method, 'updateFromImport', '...calls the nodes updateFromImport method.');
    is($args->[1], $node, '...with the new node as an argument.');
    is($args->[2], -1, '...and the superuser.');

    $instance->update_node_to_nodebase( $node );

    ( $method, $args ) = $node->next_call;

    is( $method, 'existingNodeMatches', '....checks to see whether a node is matching.');

    ( $method, $args ) = $oldnode->next_call;

   ( $method, $args ) = $node->next_call;
    is($method, 'insert', '...calls the nodes insert method.');
    is($args->[1], -1, '...and the superuser.');

}

sub test_update_nodebase_from_nodeball : Test(11) {
    my $self = shift;

    can_ok( $self->{class}, 'update_nodebase_from_nodeball' )
      || return 'update_nodeball not implemented.';

    my $instance =
      Test::MockObject::Extends::InsideOut->new( $self->{instance} );

    $instance->set_always( nodeball_xml => 'some xml' );
    $instance->set_always( -nodeball_vars => { title => 'foobar' } );
    $instance->set_true( 'insert_sql_tables', 'update_node_to_nodebase',
        'fix_node_references' );

    my $mock = $self->{mock};
    $mock->set_always( getNode => $mock );
    $mock->set_true('updateFromImport');
    $instance->set_nodebase($mock);
    $instance->set_list( 'build_new_nodes' => $mock, $mock );

    $instance->update_nodebase_from_nodeball;

    my ( $method, $args ) = $instance->next_call;
    is( $method, 'nodeball_xml', '...reads XML nodeball.' );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'insert_sql_tables', '...tries to insert all sql tables.' );
    ( $method, $args ) = $instance->next_call;
    is( $method, 'build_new_nodes',
        '...turns all new nodes into node objects.' );
    ( $method, $args ) = $instance->next_call;
    is( $method, 'update_node_to_nodebase',
'...inserts/updates the node into the nodebase according to the algorithm.'
    );
    is( $$args[1], $mock, '...calls with the newly created node object.' );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'update_node_to_nodebase',
'...inserts/updates the node into the nodebase according to the algorithm.'
    );
    is( $$args[1], $mock, '...calls with the newly created node object.' );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'fix_node_references', '...fixes references.' );

    ( $method, $args ) = $mock->next_call(2);
    is( $method, 'updateFromImport',
        '...calls updateFromImport against the old nodeball.' );

    ( $method, $args ) = $instance->next_call;
    is( $method, 'fix_node_references', '...and finally fixes references.' );

}

sub test_check_named_tables : Test(3) {
    my $self = shift;

    can_ok( $self->{class}, 'checkNamedTables' )
      || return 'checkNamedTables not implemented.';

    my $test_code = \&{ $self->{class} . '::checkNamedTables' };
    my $mock      = $self->{mock};
    $mock->{storage} = $mock;
    $mock->mock( parse_sql_file => \&parse_sql_file_returns );

    ### these are the columns we already have
    my @getFieldsHash_returns = (
        [qw/from_address mail_id/],
        [
            qw/type_nodetype dynamicguest_permission author_user otheraccess groupaccess title/
        ]
    );
    $mock->mock( 'getFieldsHash' =>
          sub { my $r = shift @getFieldsHash_returns; return @{$r}; } );
    my $dir = get_temp_dir;
    mkdir $dir;

    my $sql_file = File::Spec->catfile( $dir, 'somedata.sql' );
    my $fh       = IO::File->new( $sql_file,  'w' );
    print $fh "stuff";
    close $fh;

    my $rv = $test_code->( [qw/mail node/], $dir, $mock );

    is_deeply(
        $rv,
        { node => [qw/createtime node_id/] },
        '...reports missing tables.'
    );

    #try different returns
    @getFieldsHash_returns = (
        [qw/from_address mail_id/],
        [
            qw/type_nodetype dynamicguest_permission author_user otheraccess groupaccess title createtime node_id/
        ]
    );

    $rv = $test_code->( [qw/mail node/], $dir, $mock );

    is_deeply( $rv, undef, '...returns undef if tables are the same.' );

    rmtree $dir;
}

sub test_check_tables : Test(11) {
    my $self = shift;

    can_ok( $self->{class}, 'checkTables' )
      || return 'checkTables not implemented.';
    local $TODO = "checkTables model needs to change. Unimplemented.";

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

sub test_export_nodeball_to_directory : Test(4) {
    my $self = shift;

    my $instance= Test::MockObject::Extends::InsideOut->new( $self->{instance} );
    my $mock = $self->{mock};
    $mock->set_always( getNode => $mock );
    $mock->set_always( 'selectNodegroupFlat' => [$mock, $mock, $mock] );
    $instance->set_nodebase( $mock );

    $instance->set_true('write_node_to_nodeball');
    can_ok( $self->{class}, 'export_nodeball_to_directory' );


    my @toXMLReturns = ('me file contents', 'data');

    local *Everything::XML::Node::toXML;
    *Everything::XML::Node::toXML = sub { shift @toXMLReturns };

    ### calls update_nodeball_from_nodebase;
    $instance->export_nodeball_to_directory('nodeballname', 'tmpdir');
    my ($method, $args) = $mock->next_call;
    is( "$method..$$args[1]$$args[2]", 'getNode..nodeballnamenodeball', '.... read nodeball data.' );

    ($method, $args) = $instance->next_call;
    is( "$method$$args[1]$$args[2]", "write_node_to_nodeball${mock}ME", '....create ME file and put nodeball data into it.' );

    my $nodedata;
    for (1..3) {
	($method, $args) = $instance->next_call;
	$nodedata .= "$method$$args[1]";
    }
    is( $nodedata, "write_node_to_nodeball$mock" x 3, '...export each node in the nodeball group as xml.' );

}

sub test_remove_nodeball : Test( 5 ) {
    my $self = shift;
    local $TODO =
"Methods to remove a nodeball from an installation checking for dependencies.";
    can_ok( $self->{class}, 'remove_nodeball' );

    ok( undef, '...retrieve group of nodes in nodeball.' );
    ok( undef,
        '...process conflicts algorith - is a node also in another ball?' );
    ok( undef, '...delete node if can according to above algoithm.' );
    ok( undef, '...delete nodeball node itself.' );

}

sub test_make_node_iterator : Test( 9 ) {

    my $self     = shift;
    my $instance = $self->{instance};
    can_ok( $self->{class}, 'make_node_iterator' ) || return;

    my $test_nodeball_d = $self->{test_nodeball_d};
    $instance->set_nodeball_dir($test_nodeball_d);
    my $iterator = $instance->make_node_iterator();

    for ( 1 .. 4 ) {
        isa_ok( $iterator->(), 'Everything::XML::Node',
            '...returns an Everything::XML::Node object.' );
    }

    is( $iterator->(), undef, '...returns undef when no more nodes' );

    ### test the callback works

    my @list = qw/first second/;
    my $cb = sub {
        my ($xmlnode) = @_;
        return unless my $value = shift @list;
        $xmlnode->set_title($value);
        return 1;
    };

    $iterator = $instance->make_node_iterator($cb);

    is( $iterator->()->get_title,
        'first', '...returns an Everything::XML::Node object.' );
    is( $iterator->()->get_title,
        'second', '...returns an Everything::XML::Node object.' );

    is( $iterator->(), undef, '...returns undef when no more nodes' );

}

sub test_write_sql_table_to_nodeball : Test(3) {

    my $self = shift;

    return unless can_ok( $self->{class}, 'write_sql_table_to_nodeball' );

    my $instance = $self->{instance};
    my $mock     = $self->{mock};

    use Everything::DB::sqlite;
    $mock->{storage} = Everything::DB::sqlite->new;

    my @get_create_table_args;
    local *Everything::DB::sqlite::get_create_table;
    *Everything::DB::sqlite::get_create_table =
      sub { push @get_create_table_args, $_[1]; return 'create statement' };

    my $tempdir = get_temp_dir();
    mkdir $tempdir;
    $instance->set_nodebase($mock);
    $instance->set_nodeball_dir($tempdir);

    my $rv = $instance->write_sql_table_to_nodeball('atable');

    is( $get_create_table_args[0],
        "atable", '...asks for table passed as argument.' );
    my $file =
      File::Spec->catfile( $instance->get_nodeball_dir, 'tables', 'SQLite',
        'atable.sql' );
    my $fh = IO::File->new($file) || die "Can't open $file, $!";
    local $/;
    my $sql = <$fh>;
    close $fh;
    is(
        $sql,
        'create statement',
        '...writes the create statement to an appropriately named file'
    );

}


sub test_write_node_to_nodeball :Test(3) {

    my $self = shift;
    my $instance = $self->{instance};
    my $mock = $self->{mock};

    return unless can_ok( $self->{class}, 'write_node_to_nodeball');

    local *Everything::XML::Node::new;
    *Everything::XML::Node::new = sub { $mock };
    $mock->set_always( 'toXML' => 'some xml' );

    $mock->{ title } = 'a node title';
    $mock->{ type } = { title  => 'a node type title' };

    $instance->set_nodeball_dir( get_temp_dir() );

    ## a node object is passed as the argument
    my $rv = $instance->write_node_to_nodeball( $mock );

    ( my $title = $$mock{title} ) =~ s/\s/_/g;
    my $dir = $$mock{type}{title};
    $dir =~ s/\s/_/g;
    $title .= '.xml';
    my $file =  File::Spec->catfile( $instance->get_nodeball_dir , 'nodes', $dir, $title );
    my $fh = IO::File->new( $file ) || die "Can't open file, $file, $!";
    local $/;
    my $sql = <$fh>;
    close $fh;

    is ( $sql, 'some xml', '...writes the XML to the selected file.');

    ### Now with our own filepath
    $rv = $instance->write_node_to_nodeball( $mock, 'filepath' );
    $fh = IO::File->new( File::Spec->catfile( $instance->get_nodeball_dir , 'filepath' ));

    $sql = <$fh>;
    close $fh;
    is ( $sql, 'some xml', '...writes the XML to the filename of our choosing.');

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

sub test_update_nodeball_from_nodebase :Test(6) {
    local $TODO = 'Unimplemented.';
    my $self = shift;

    #### does almost everything by called write_node_to_nodeball

    can_ok( $self->{class}, 'update_nodeball_from_nodebase' ) || return "Unimplemented";

    local *Everything::XML::Node;
    *Everything::XML::Node::toXML = sub { 'some xml' };

    ok( undef, '...create new ME file.');

    ok( undef, '...replace new ME file with old one.');

    ok( undef, '...remove dbtables not in new ME file.');

    ok( undef, '...remove nodes not in new ME file.');

    ok( undef, '...run through nodeball members with modified dates greater than createtime (of nodeball) and save them.');

}

sub test_check_nodeball_integrity :Test(4) {

    my $self = shift;
    my $instance = $self->{instance};

    my $dir = get_temp_dir();
    mkdir $dir;

    $instance->set_nodeball_dir( $dir );

    my $mefile =  File::Spec->catfile ($dir, 'ME');
    my $fh = IO::File->new;
    $fh->open( $mefile, 'w' ) || die "Can't open $mefile, $!";
    print $fh <<HERE;
<NODE export_version="0.5" nodetype="nodeball" title="core system">
  <group>
    <member name="group_node" type="noderef" type_nodetype="theme,nodetype">default theme</member>
    <member name="group_node" type="noderef" type_nodetype="superdoc,nodetype">Create a new user</member>
    <member name="group_node" type="noderef" type_nodetype="superdoc,nodetype">Duplicates Found</member>
</group>
</NODE>
HERE
    $fh->close;
    my $one = Everything::XML::Node->new;
    $one->set_title('Create a new user');
    $one->set_nodetype( 'htmlcode' );

    my $two = Everything::XML::Node->new;
    $two->set_title('thingo');
    $two->set_nodetype( 'thingotype' );

    my $three = Everything::XML::Node->new;
    $three->set_title('default theme');
    $three->set_nodetype( 'theme' );

    my @xmlnodes = ( $one, $two, $three );
    no strict 'refs';
    local *{ $self->{class} . '::make_node_iterator' };
     *{ $self->{class} . '::make_node_iterator' } = sub { sub { shift @xmlnodes }};
    use strict 'refs';

    my ($not_in_ME, $not_in_nodeball) = $instance->check_nodeball_integrity;

    my @sorted = sort { $a->{title} cmp $b->{title} } @$not_in_ME;
    is($sorted[0]->{title}, 'Create a new user', '...not in ME when titles same but types are different.');
    is($sorted[1]->{title}, 'thingo', '...not in ME when title not presnet.');

    @sorted = sort { $a->{title} cmp $b->{title} } @$not_in_nodeball;
    is($sorted[0]->{title}, 'Create a new user', '...not in nodeball when titles same but types are different.');
    is($sorted[1]->{title}, 'Duplicates Found', '...not in nodeball when title not present.');


}

sub test_verify_nodes : Test(3) {
    my $self = shift;

    my $instance = $self->{instance};
    my $mock     = $self->{mock};

    $instance->set_nodebase($mock);

    local *Everything::Storage::Nodeball::verify_node;
    *Everything::Storage::Nodeball::verify_node = sub { 'verified' };

    local *Everything::Storage::Nodeball::nodeball_vars;
    *Everything::Storage::Nodeball::nodeball_vars =
      sub { { title => 'nodeballname' } };

    my @returns = ( $mock, $mock, $mock );
    local *Everything::Storage::Nodeball::make_node_iterator;
    *Everything::Storage::Nodeball::make_node_iterator = sub {
        sub { shift @returns }
    };

    $mock->set_always( selectGroupArray => [ 1 .. 4 ] );
    $mock->set_series(
        getNode => $mock,
        $mock, $mock, $mock, $mock, undef, $mock, $mock, $mock, $mock, $mock,
        $mock, $mock
    );
    $mock->set_always( get_nodetype => 'anodetype' );
    $mock->set_series( get_title => qw/title1 title2 title3 title4/ );
    $mock->{title} = 'node title';
    $mock->{type}  = $mock;

    my ( $in_nodeball, $in_nodebase, $diffs ) = $instance->verify_nodes;

    is_deeply( $in_nodeball, [$mock], '...returns an array ref.' );

    is_deeply( $in_nodebase, [$mock], '...returns an array ref.' );

    is_deeply(
        $diffs,
        [ [ $mock, 'verified' ], [ $mock, 'verified' ], ],
        '...returns an array ref.'
    );
}

sub test_verify_node : Test(19) {
    my $self     = shift;
    my $instance = $self->{instance};
    my $xmlnode  = Test::MockObject->new;
    my $node     = Test::MockObject->new;
    my $mock = $self->{mock};

    $instance->set_nodebase( $self->{mock} );
    $self->{mock}->set_always( getNode => $self->{mock} );
    $self->{mock}->{title} = 3;
    $self->{mock}->{node_id} = 123;
    $mock->set_always( get_node_id => 123 );

    $xmlnode->set_always( 'get_attributes', [ $xmlnode, $xmlnode ] );

    $xmlnode->set_always( get_vars          => [] );
    $xmlnode->set_always( get_group_members => [] );

    $xmlnode->set_always( get_title         => 'node name' );
    $xmlnode->set_always( get_nodetype      => 'a nodetype' );
    $xmlnode->set_series( get_name          => 'attribute_name', 'attribute_name','attribute_name','attribute_name', 'att2', 'att2', 'att2', 'att2' );
    $xmlnode->set_always( get_content       => 'attribute content' );
    $xmlnode->set_always( get_type_nodetype => 'anodetype,nodetype' );
    $xmlnode->set_series( get_type => 'literal_value', 'literal_value', 'noderef', 'noderef' );

    $node->set_always(get_attribute_name => 'attribute content');
    $node->{'att2'} = 123;
    $node->set_always('get_att2' => 123);
    $node->mock( selectGroupArray => sub { die } );

    my $rv = $instance->verify_node( $xmlnode, $node );

    is( $rv, undef, '...if the same returns nothing.' );

    $xmlnode->set_series( get_name          => 'attribute_name', 'attribute_name', 'att2', 'att2', 'att2', 'att2' );
    $xmlnode->set_series( get_type => 'literal_value', 'noderef' );
    $node->set_always('get_attribute_name' => 'different content');
    $node->set_always('get_att2' => 456);
    $mock->set_always( get_title => 'anodetitle' );
    $mock->set_always( get_type => $mock);

    my @ids = ( 123, 456 );
    $mock->mock( get_node_id => sub { shift @ids } );
    $rv = $instance->verify_node( $xmlnode, $node );

    my @diff = sort { $b->get_name cmp $a->get_name } @$rv;

    ok (! $diff[0]->is_noderef, '...is a literal value.');

    is( $diff[0]->get_nb_node_content, 'different content', '...returns content from nodebase' );
    is( $diff[0]->get_xmlnode_content, 'attribute content', '...returns content from nodeball.' );

    ok ( $diff[1]->is_noderef, '...returns a node reference.');

    is( $diff[1]->get_nb_node_ref_name, 'anodetitle', '...returns node name of reference' );
    is( $diff[1]->get_xmlnode_ref_name, 'attribute content', '...returns nodename of reference in nodeball.' );

    is( $diff[1]->get_nb_node_ref_type, 'anodetitle', '...returns nodetype of reference in nodebase.' );
    is( $diff[1]->get_xmlnode_ref_type, 'anodetype', '...returns nodetype of reference in nodeball.' );


    #Now test vars


    @ids = ( 123, 456 );
    $node->set_always( getVars => { varname1 => 'varvalue', varname2 => 123 } );
    $xmlnode->set_series( get_name          => 'varname1', 'varname1', 'varname2', 'varname2' );
    $xmlnode->set_always( 'get_attributes' => [] );
    $xmlnode->set_always( get_vars          => [ $xmlnode, $xmlnode] );
    $xmlnode->set_always( get_group_members => [] );
    $xmlnode->set_series( get_type => 'literal_value', 'noderef' );
    $self->{mock}->{title} = "Title of a node retrieved from db.";
    $self->{mock}->{node_id} = 456;
    $rv = $instance->verify_node( $xmlnode, $node );

    @diff = sort { $a->get_name cmp $b->get_name } @$rv;

    ok (! $diff[0]->is_noderef, '...is var a literal value.');

    is( $diff[0]->get_nb_node_content, 'varvalue', '...returns var content from nodebase' );
    is( $diff[0]->get_xmlnode_content, 'attribute content', '...returns var content from nodeball.' );

    ok ( $diff[1]->is_noderef, '...returns a node reference.');

    is( $diff[1]->get_nb_node_ref_name, 'anodetitle', '...returns node name of reference from var' );
    is( $diff[1]->get_xmlnode_ref_name, 'attribute content', '...returns nodename of reference in nodeball from var.' );

    is( $diff[1]->get_nb_node_ref_type, 'anodetitle', '...returns nodetype of reference in nodebase from var.' );
    is( $diff[1]->get_xmlnode_ref_type, 'anodetype', '...returns nodetype of reference in nodeball var.' );

    #Now test group members

    $xmlnode->set_series( get_name          => 'member1', 'member2' );
    $xmlnode->set_always( 'get_attributes' => [] );
    $xmlnode->set_always( get_vars          => [] );
    $xmlnode->set_always( get_group_members => [ $xmlnode, $xmlnode ] );
    $xmlnode->set_series( get_type => 'literal_value', 'noderef' );
    $node->set_always( selectGroupArray => [ 1, 2 ] );
    $node->set_always( get_type => $node );
    $node->set_always( get_node_id => 1);
    $node->set_always( get_title => 'The node title');
    $mock->set_always( get_title => "dbnode");
    $mock->set_always( get_type => $mock );
    $mock->set_always( get_node_id => 123 );

    $rv = $instance->verify_node( $xmlnode, $node );

    my ( $diff ) = @$rv;
    is_deeply(
        $diff->get_xmlnode_additional,
	     [ {
	       name => 'member1',
	       type => 'anodetype'
	      },
	       {
	       name => 'member2',
		type => 'anodetype'
	       }
		]
	      ,
        '...returns an array ref of hash refs with name & type keys.'
    );

    my $nodes = $diff->get_nb_node_additional;
    is ( $$nodes[0]->get_title . $$nodes[0]->get_type->get_title, 'dbnodedbnode', '...returns nodes not in nodeball.');


}


sub parse_sql_file_returns {

    (
        q{CREATE TABLE "themesetting" (
  "themesetting_id" bigint DEFAULT '0' NOT NULL,
  "parent_theme" bigint DEFAULT '0' NOT NULL,
  PRIMARY KEY ("themesetting_id")
)},
        q{BEGIN TRANSACTION},
        q{DROP TABLE IF EXISTS mail},
        q{CREATE TABLE mail (
  mail_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  from_address char(80) NOT NULL DEFAULT ''
)},
        q{CREATE TABLE node (
  node_id int(11) NOT NULL auto_increment,
  type_nodetype int(11) DEFAULT '0' NOT NULL,
  title char(240) DEFAULT '' NOT NULL,
  author_user int(11) DEFAULT '0' NOT NULL,
  createtime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  groupaccess char(5) DEFAULT 'iiiii' NOT NULL,
  otheraccess char(5) DEFAULT 'iiiii' NOT NULL,
  dynamicguest_permission int(11) DEFAULT '-1' NOT NULL,
  PRIMARY KEY (node_id),
  KEY title (title,type_nodetype),
  KEY author (author_user),
  KEY type (type_nodetype)
)}
    );

}


package Test::MockObject::Extends::InsideOut;

use SUPER;
use base 'Test::MockObject::Extends';

our $AUTOLOAD;

sub new {
    my ( $class, $fake_class ) = @_;

    return Test::MockObject->new() unless defined $fake_class;

    my $parent_class = $class->get_class($fake_class);
    $class->check_class_loaded($parent_class);
    my $self = { _oio => $fake_class };

    bless $self, $class->gen_package($parent_class);
}

sub gen_package {
    my ( $class, $parent ) = @_;
    my $package = $class->SUPER($parent);

    eval qq|package $package;
use overload 
  '\${}' => sub { return shift()->{_oio} },
|;

    die "Can't overload scalar dereferencing, $@" if $@;
    no strict 'refs';

    *{ $package . '::DESTROY' } =
      sub { shift()->{_oio}->DESTROY };

    return $package;
}

1;
