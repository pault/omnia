package Everything::Storage::Test::Nodeball;

use base 'Everything::Test::Abstract';
use Test::More;
use File::Spec;
use Test::Exception;
use Test::MockObject;
use File::Temp;
use File::Path;
use File::Find;
use Archive::Tar;
use IO::File;
use SQL::Statement;
use Cwd;
use strict;
use warnings;

sub startup : Test(+1) {
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
    $mock->fake_module( 'IO::File', 'new', sub { $fh } );
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
    $mock->fake_module( 'IO::File', 'new', sub { } );
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

sub test_update_nodeball : Test(6) {
    my $self = shift;

    can_ok( $self->{class}, 'update_nodeball' )
      || return 'update_nodeball not implemented.';
    my $instance = $self->{instance};

    local $TODO = "Analyse, break down and fix update nodeball.";

    my $mock = Test::MockObject->new;
    ok( undef, '...reads XML nodeball.' );
    ok( undef,
        '...finds nodes in old nodeball that have been modified since install.'
    );
    ok( undef, '...workspaces updated new nodes if possibole.' );
    ok( undef, '...if not then asks for instructions.' );
    ok( undef, '...updates nodeball data.' );
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
    use Data::Dumper;
    print Dumper $rv;
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

sub test_export_nodeball : Test(7) {
    my $self = shift;
    local $TODO = "Methods to export a nodeball stored in a nodebase.";
    can_ok( $self->{class}, 'export_nodeball' );

    ok( undef, '.... read nodeball data.' );

    ok( undef, '....create ME file and put nodeball data into it.' );

    ok( undef, '...create table sql files.' );

    ok( undef, '...export each node in the nodeball group as xml.' );

    ok( undef, '...compress nodeball and name it .nbz file.' );

    ok( undef, '...clean up working directory.' );
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
1;
