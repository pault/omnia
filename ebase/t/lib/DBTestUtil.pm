package DBTestUtil;

use base 'Exporter';
use Everything::Config;
use Everything::Storage::Nodeball;
use File::Path;
use IO::File;
use File::Spec;
use File::Temp;
use Test::More;

our @EXPORT_OK = qw/config_file drop_database skip_cond nodebase update_node_tests delete_node_tests nodeball_script_tests/;


sub config_file {

    my $db_type = db_type();
    return "t/lib/db/$db_type.conf";

}

sub db_type {

   $0 =~ m|t/ecore/(.*?)/\d{3}\-[\w-]+\.t$|;
   return $1 if $1;
   $0 =~ m|(\w+)\.t$|;
   return $1;

}

sub drop_database {

    my $config_file = config_file();
    my $config = Everything::Config->new(  file => $config_file );

    my $storage_class = 'Everything::DB::' . $config->database_type;

    ( my $file = $storage_class ) =~ s/::/\//g;
    $file .= '.pm';
    require $file;

    $storage_class->drop_database (
	$config->database_name,
        $config->database_superuser,
	$config->database_superpassword,
	$config->database_host,
	$config->database_port,
				  );


}

sub skip_cond {
    my ( $class ) = @_;

    my $run_tests = 't/lib/db/run-tests';

    my $config_file = config_file();

    my $msg = '';


    if ( ! -e $run_tests  ) {

	return "Time consuming DB tests skipped by default.  Touch '$run_tests' to run.";

    } elsif ( ! -e $config_file ) {

	return "The config file '$config_file' must exist to run these tests.";
    }

    return;

}

sub nodebase {

    my $config = Everything::Config->new( file => config_file() );
    return $config->nodebase;


}

sub update_node_tests {

    my $skip = skip_cond();
    my ( $nodebase, $count );

## For more sophisticated tests later.
     my %test_fields = (
     		 container => 'context',
     		 htmlcode => 'code',
     		 htmlpage => 'page',
     		 htmlsnippet => 'code',
     		 image => 'src',
     		 javascript => 'code',
     		 mail => 'doctext',
     		 nodelet => 'nlcode',
    		 nodemethod => 'code',
     		 opcode => 'code',
     		 restricted_superdoc => 'doctext',
     		 superdoc => 'doctext'
    );

    if ($skip) {
        plan skip_all => $skip;
    }
    else {

        $nodebase = nodebase();
	$count = 0;
	for ( keys %test_fields ) {
	    $count += ( $nodebase->countNodeMatches( {}, $_ ) ) * 2;
	}

        plan tests => $count;

    }

    my $user = $nodebase->getNode( 'root', 'user' );
    my $test_data = 'test data';

    for my $nodetype ( keys %test_fields ) {

        my $nodes = $nodebase->getNodeWhere( undef, $nodetype );
        for my $node (@$nodes) {

	    my $field = $test_fields{$nodetype};
            my $save = $node->{ $field };
	    my $id = $node->getId;

	    $node->{ $field } = $test_data;

            ok( $node->update($user),
                $node->get_title . ' id: ' . $node->getId . ' updates ok.' );
            is( $nodebase->getNode($id)->{$field}, $test_data, '..the updated field is set value.' );

	    # reset values
	    $node = $nodebase->getNode($id);
	    $node->{$field} = $save;
	    $nodebase->update_stored_node( $node, $user );
        }
    }

}

sub delete_node_tests {

    my $skip = skip_cond();
    my ( $nodebase, $count, $nodes );

    if ($skip) {
        plan skip_all => $skip;
    }
    else {

        $nodebase = nodebase();

        ## get all nodes that aren't nodetypes

        my @exclude = qw/nodetype dbtable/;

        my @exclude_ids =
          map { $_->get_node_id }
          map { $nodebase->getNode( $_, 'nodetype' ) } @exclude;

        my $where_clause = join ' AND ',
          map ( "type_nodetype != $_", @exclude_ids );

        $nodes = $nodebase->getNodeWhere($where_clause);

        my $count = 0;
        foreach (@$nodes) {
            my @tables = $_->dbtables;
            $count += 1 + scalar(@tables);
            $count++ if $_->isGroup;
        }

        plan tests => $count;

    }

    local *Everything::logErrors;
    *Everything::logErrors = sub { diag "@_"; };

    for my $node (@$nodes) {

        my @tables    = $node->dbtables;
        my ( $node_name, $type_name ) = ( $node->get_title, $node->type->get_title );

        ok( $node->nuke(-1), ".. deleted '$node_name' of type '$type_name'." );

        foreach my $table (@tables) {
            ok(
                !$nodebase->sqlSelectHashref(
                    '*', $table, "${table}_id = " . $node->get_node_id()
                ),
                "...no entry in table $table"
            );

        }

        if ( my $grouptable = $node->isGroup ) {

            ok(
                !$nodebase->sqlSelectHashref(
                    '*', $grouptable,
                    "${grouptable}_id = " . $node->get_node_id()
                ),
                "...no group entry in table $grouptable"
            );

        }

    }

}

sub nodeball_script_tests {

    my $ball = '../ecore';

    my $config_file = config_file();

    my @config_args;

    push @config_args, file => $config_file if -e $config_file;

    my $skip = skip_cond();

    if ($skip) {

        plan skip_all => $skip;

    }
    else {

        plan tests => 11;

    }

    my $ball_dir = File::Temp::tempdir( CLEANUP => 1 );

    mkpath( File::Spec->catfile( $ball_dir, 'nodes', 'document' ) );
    my $fh =
      IO::File->new(
        File::Spec->catfile( $ball_dir, 'nodes', 'document', 'test_doc.xml' ),
        'w' )
      || die "Can't open temp file, $!";

    print $fh <<NODE;

<NODE export_version="0.5" nodetype="document" title="Test doc node">
  <field name="author_user" type="noderef" type_nodetype="user,nodetype">root</field>
  <field name="authoraccess" type="literal_value">iiii</field>
  <field name="doctext" type="literal_value">Some text in a test doc</field>
  <field name="groupaccess" type="literal_value">iiiii</field>
  <field name="guestaccess" type="literal_value">iiiii</field>
  <field name="loc_location" type="noderef" type_nodetype="location,nodetype">document</field>
  <field name="otheraccess" type="literal_value">iiiii</field>
  <field name="title" type="literal_value">Test doc node</field>
  <field name="type_nodetype" type="noderef" type_nodetype="nodetype,nodetype">document</field>
</NODE>

NODE

    $fh->close;

    # Now add the nodeball data

    $fh = IO::File->new( File::Spec->catfile( $ball_dir, 'ME' ), 'w' );

    print $fh <<NODEBALL;

<NODE export_version="0.5" nodetype="nodeball" title="test nodeball">
  <field name="author_user" type="noderef" type_nodetype="user,nodetype">root</field>  <field name="authoraccess" type="literal_value">iiii</field>
  <field name="title" type="literal_value">test nodeball</field>
  <group>
    <member name="group_node" type="noderef" type_nodetype="document,nodetype">Test doc node</member>
  </group>
</NODE>

NODEBALL

    $fh->close;

    my $config = Everything::Config->new( file => $config_file );

    my $nodebase = $config->nodebase;

    my $db_name = $config->database_name;
    my $db_user = $config->database_user;
    my $db_pass = $config->database_password;
    my $db_type = $config->database_type;
    my $db_port = $config->database_port;

    my @args = (
        '-d', $db_name, '-u', $db_user, '-p', $db_pass,
        '-t', $db_type, '-P', $db_port, $ball_dir
    );

    my @script = ( 'perl', '-Ilib', 'bin/insert_nodeball.pl' );

    system(  @script, @args );
    ok( $? == 0, '...install script runs.' );

    my $nodeball_node = $nodebase->getNode( 'test nodeball', 'nodeball' );
    my $test_node     = $nodebase->getNode( 'Test doc node', 'document' );

    ok( $nodeball_node, 'Node ball is installed.' );

    isa_ok( $test_node, 'Everything::Node::document',
        'the test document node is installed.' );

## is the test node in the nodeball
    is_deeply(
        $nodeball_node->get_group,
        [ $test_node->getId ],
        'the document node is in the nodeball.'
    );

# XXX: use open3 to capture the STDERR or the system call to ensure it is warning correctly.
    system( @script, @args );
    ok(
        $? != 0,
'The install script refuses to install if the the nodeball is already installed.'
    );

## Now let's try to update the nodeball

    $fh =
      IO::File->new(
        File::Spec->catfile( $ball_dir, 'nodes', 'document', 'test_doc.xml' ),
        'w' )
      || die "Can't open temp file, $!";

    print $fh <<NODE;

<NODE export_version="0.5" nodetype="document" title="Test doc node">
  <field name="author_user" type="noderef" type_nodetype="user,nodetype">root</field>
  <field name="authoraccess" type="literal_value">iiii</field>
  <field name="doctext" type="literal_value">Some amended text in a doc</field>
  <field name="groupaccess" type="literal_value">iiiii</field>
  <field name="guestaccess" type="literal_value">iiiii</field>
  <field name="loc_location" type="noderef" type_nodetype="location,nodetype">document</field>
  <field name="otheraccess" type="literal_value">iiiii</field>
  <field name="title" type="literal_value">Test doc node</field>
  <field name="type_nodetype" type="noderef" type_nodetype="nodetype,nodetype">document</field>
</NODE>

NODE

    $fh->close;

    pop @script;
    push @script, 'bin/update_nodeball.pl';

    system( @script, @args );
    ok( $? == 0, 'The update script runs.' )
      || diag "System call return value is " . ( $? >> 8 );

    $test_node = $nodebase->getNode( 'Test doc node', 'document' );

    is(
        $test_node->get_doctext,
        'Some amended text in a doc',
        '...and updates the document.'
    );

## Now test what happens to an update if the node is already modfied

    $test_node = $nodebase->getNode( 'Test doc node', 'document' );

    $test_node->set_doctext('Set modified flag');

    $nodebase->update_stored_node( $test_node, -1 )
      || diag "Failed to update node";

    $fh =
      IO::File->new(
        File::Spec->catfile( $ball_dir, 'nodes', 'document', 'test_doc.xml' ),
        'w' )
      || die "Can't open temp file, $!";

    print $fh <<NODE;

<NODE export_version="0.5" nodetype="document" title="Test doc node">
  <field name="author_user" type="noderef" type_nodetype="user,nodetype">root</field>
  <field name="authoraccess" type="literal_value">iiii</field>
  <field name="doctext" type="literal_value">Some amended text in a doc</field>
  <field name="groupaccess" type="literal_value">iiiii</field>
  <field name="guestaccess" type="literal_value">iiiii</field>
  <field name="loc_location" type="noderef" type_nodetype="location,nodetype">document</field>
  <field name="otheraccess" type="literal_value">iiiii</field>
  <field name="title" type="literal_value">Test doc node</field>
  <field name="type_nodetype" type="noderef" type_nodetype="nodetype,nodetype">document</field>
</NODE>

NODE

    $fh->close;

    system( @script, @args );
    ok( $? == 0, 'The update script runs.' )
      || diag "System call return value is " . ( $? >> 8 );

    $test_node = $nodebase->getNode( 'Test doc node', 'document' );

    is(
        $test_node->get_doctext,
        'Set modified flag',
        '...but the document is not updated.'
    );

## Now try to export the nodeball

    pop @args;
    my $export_dir = File::Temp::tempdir( CLEANUP => 1 );

    push @args, 'test nodeball', $export_dir;

    pop @script;
    push @script, 'bin/export_nodeball.pl';

    system( @script, @args );
    ok( $? == 0, 'The export script runs.' )
      || diag "System call return value is " . ( $? >> 8 );

    my $test_ball = Everything::Storage::Nodeball->new(
        nodeball => $export_dir,
        nodebase => $nodebase
    );

    my ( $in_ball, $in_base, $diffs ) = $test_ball->verify_nodes;

    is_deeply(
        [ $in_ball, $in_base, $diffs ],
        [ [], [], [], ],
        '...the exported nodes are identifcal to the ones in the nodebase.'
    ) || diag Dumper $in_ball, $in_base, $diffs;

}

1;
