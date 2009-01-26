package DBTestUtil;

use base 'Exporter';
use Everything::Config;
use Test::More;

our @EXPORT_OK = qw/config_file drop_database skip_cond nodebase update_node_tests delete_node_tests/;


sub config_file {

    my $db_type = db_type();
    return "t/lib/db/$db_type.conf";

}

sub db_type {

   $0 =~ m|t/ecore/(.*?)/\d{3}\-[\w-]+\.t$|;
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
	$config->database_superpassword
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

    if ($skip) {
        plan skip_all => $skip;
    }
    else {

        $nodebase = nodebase();
        $count = $nodebase->countNodeMatches( {} );
        plan tests => $count * 2;

    }

## For more sophisticated tests later.
    # my %test_fields = (
    # 		 container => 'context',
    # 		 htmlcode => 'code',
    # 		 htmlpage => 'page',
    # 		 htmlsnippet => 'code',
    # 		 image => 'src',
    # 		 javascript => 'code',
    # 		 mail => 'doctext',
    # 		 nodelet => 'nlcode',
    # 		 nodemethod => 'code',
    # 		 opcode => 'code',
    # 		 restricted_supercode => 'doctext',
    # 		 superdoc => 'doctext',
    #);

    my $user = $nodebase->getNode( 'root', 'user' );

    for ( 1 .. $count ) {
        my $node = $nodebase->getNode($_);
        $node->set_hits($_);
        ok( $node->update($user), '..updates ok.' );
        is( $node->get_hits, $_, '..the updated field is set value.' );
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

	my @nodetypes = ( container,
htmlcode,
htmlpage,
htmlsnippet,
image,
javascript,
mail,
nodegroup,
nodelet,
nodeletgroup,
nodemethod,
opcode,
restricted_superdoc,
setting,
superdoc,
theme,
themesetting,
usergroup,
location,

); #excluding nodetype, dbtable & user

	$nodes = [];

	foreach ( @nodetypes ) {
	    push @$nodes, @{ $nodebase->getNodeWhere( {}, $_ ) || [] };
	}


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
        my ( $node_name, $type_name ) = ( $node->get_title, $node->get_type->get_title );

        ok( $node->nuke(-1), ".. deleted '$node_name' of type '$type_name'." ) || diag $DBI::errstr;

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

1;
