#!/usr/bin/perl

use Everything::NodeBase;
use Everything::Nodeball;
use Everything::CmdLine qw/get_options abs_path/;
use File::Copy;
use File::Spec;
use Test::More;
use DBI;
use Carp qw/cluck confess croak/;
use File::Temp qw/tempfile/;


use strict;
use warnings;
$SIG{__DIE__} = \&confess;


my $opts = get_options( usage() );
my %opts = %$opts;

my $ball = $ARGV[0];

usage() unless $ball;

my $tests = Everything::Test::Ecore->new;

$tests->{nodeball} = abs_path( $ball );

my %make_db = (
    mysql  => \&make_mysql_test_db,
    Pg     => \&make_Pg_test_db,
    sqlite => \&make_sqlite_test_db,
);

my $db_type = $opts{type} || 'sqlite';
my $test_db = $make_db{$db_type}->( \%opts );

my $nb = Everything::NodeBase->new( $test_db, 1, $db_type );
$tests->{nb}           = $nb;
$tests->{db_type}      = $db_type;
$tests->{base_test_db} = $test_db;

$tests->runtests;

my $tests_run = $tests->expected_tests;
my $builder   = $tests->builder;

my @tests = $builder->summary;

my @failed;
foreach ( 0 .. $#tests ) {
    push @failed, $_ unless $tests[$_];
}

print "\nNumber of Tests run: "
  . scalar(@tests)
  . " of $tests_run expected tests";

if (@failed) {
    print "\nList of failed tests: @failed";
}
else {
    print "\nAll tests succesful.";
}

print "\n";

exit;

#### this sets up a clean sqlite database

sub make_sqlite_test_db {
    my $opts = shift;


    my $tempdir = File::Temp::tempdir( CLEANUP => 1 );
    my $test_db = $opts{database} || File::Spec->catfile( $tempdir, 'ecore_test.db' );
    my $dbh     = DBI->connect( "dbi:SQLite:dbname=$test_db", "", "" )
      or die "No test database, $!";

    foreach ( sqlite_base_tables() ) {
        $dbh->do($_);
        croak("$_, $DBI::errstr") if $DBI::errstr;
    }

    foreach ( mysql_base_nodes() ) {
        $dbh->do($_);
        croak("$_, $DBI::errstr") if $DBI::errstr;
    }

    return $test_db;
}

sub make_mysql_test_db {
    my ($opts) = @_;
    my $host = $$opts{host} || 'localhost';
    my $user = $$opts{user} || $ENV{USER};
    my $password = $$opts{password};
    my $db_name  = $$opts{database};
    my $port     = $$opts{Port} || 3306;

    my $drh = DBI->install_driver('mysql');
    my $rc  =
      $drh->func( 'createdb', $db_name, $host, $user, $password, 'admin' );
    croak($DBI::errstr) if $DBI::errstr;

    my $dbh = DBI->connect( "DBI:mysql:database=$db_name;host=$host;port=$port",
        $user, $password );
    croak($DBI::errstr) if $DBI::errstr;

    foreach ( mysql_base_tables() ) {
        $dbh->do($_);
        croak($DBI::errstr) if $DBI::errstr;
    }

    foreach ( mysql_base_nodes() ) {
        $dbh->do($_);
        croak("$_, $DBI::errstr") if $DBI::errstr;
    }

    return join( ':', $db_name, $user, $password, $host );
}

sub make_Pg_test_db {
    my ($opts) = @_;
    my $host = $$opts{host} || 'localhost';
    my $user = $$opts{user} || $ENV{USER};
    my $password = $$opts{password};
    my $db_name  = $$opts{database};
    my $port     = $$opts{Port} || 5432;

    my $dbh = DBI->connect( "DBI:Pg:dbname=$db_name;host=$host;port=$port",
        $user, $password )
      || croak(
"$DBI::errstr, NB: you must create a Pg database before the tests can be run."
      );

    foreach ( Pg_base_tables() ) {
        $dbh->do($_);
        croak($DBI::errstr) if $DBI::errstr;
    }

    foreach ( Pg_base_nodes() ) {
        $dbh->do($_);
        croak("$_, $DBI::errstr") if $DBI::errstr;
    }

    ## ensure the node_id sequence is properly set
    $dbh->do("SELECT setval('node_node_id_seq', 3)");

    return join( ':', $db_name, $user, $password, $host );
}

sub usage {

    "\nUsage:\n\t$0 [options] <path to nodeball>\n\n";

}

sub Pg_base_tables {
    return (
        q{CREATE TABLE "setting" (
  "setting_id" serial NOT NULL,
  "vars" text default '',
  PRIMARY KEY ("setting_id")
)},
        q{CREATE TABLE "node" (
  "node_id" serial UNIQUE NOT NULL,
  "type_nodetype" bigint DEFAULT '0' NOT NULL,
  "title" character(240) DEFAULT '' NOT NULL,
  "author_user" bigint DEFAULT '0' NOT NULL,
  "createtime" timestamp NOT NULL,
  "modified" timestamp DEFAULT '-infinity' NOT NULL,
  "hits" bigint DEFAULT '0',
  "loc_location" bigint DEFAULT '0',
  "reputation" bigint DEFAULT '0' NOT NULL,
  "lockedby_user" bigint DEFAULT '0' NOT NULL,
  "locktime" timestamp DEFAULT '-infinity' NOT NULL,
  "authoraccess" character(4) DEFAULT 'iiii' NOT NULL,
  "groupaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "otheraccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "guestaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "dynamicauthor_permission" bigint DEFAULT '-1' NOT NULL,
  "dynamicgroup_permission" bigint DEFAULT '-1' NOT NULL,
  "dynamicother_permission" bigint DEFAULT '-1' NOT NULL,
  "dynamicguest_permission" bigint DEFAULT '-1' NOT NULL,
  "group_usergroup" bigint DEFAULT '-1' NOT NULL,
  PRIMARY KEY ("node_id")
)},
        q{CREATE INDEX "title" on node ("title", "type_nodetype")},
        q{CREATE INDEX "author" on node ("author_user")},
        q{CREATE INDEX "type" on node ("type_nodetype")},
        q{CREATE TABLE "nodetype" (
  "nodetype_id" serial NOT NULL,
  "restrict_nodetype" bigint DEFAULT '0',
  "extends_nodetype" bigint DEFAULT '0',
  "restrictdupes" bigint DEFAULT '0',
  "sqltable" character(255),
  "grouptable" character(40) DEFAULT '',
  "defaultauthoraccess" character(4) DEFAULT 'iiii' NOT NULL,
  "defaultgroupaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "defaultotheraccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "defaultguestaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "defaultgroup_usergroup" bigint DEFAULT '-1' NOT NULL,
  "defaultauthor_permission" bigint DEFAULT '-1' NOT NULL,
  "defaultgroup_permission" bigint DEFAULT '-1' NOT NULL,
  "defaultother_permission" bigint DEFAULT '-1' NOT NULL,
  "defaultguest_permission" bigint DEFAULT '-1' NOT NULL,
  "maxrevisions" bigint DEFAULT '-1' NOT NULL,
  "canworkspace" bigint DEFAULT '-1' NOT NULL,
  PRIMARY KEY ("nodetype_id")
)},
        q{CREATE TABLE version (
  version_id INTEGER  PRIMARY KEY DEFAULT '0' NOT NULL,
  version INTEGER DEFAULT '1' NOT NULL
)}
    );
}

sub sqlite_base_tables {
    return (
        q{CREATE TABLE setting (
  setting_id INTEGER PRIMARY KEY NOT NULL,
  vars text DEFAULT ''
)},
        q{CREATE TABLE node (
  node_id INTEGER PRIMARY KEY NOT NULL,
  type_nodetype integer(20) NOT NULL DEFAULT '0',
  title char(240) NOT NULL DEFAULT '',
  author_user integer(20) NOT NULL DEFAULT '0',
  createtime timestamp NOT NULL,
  modified timestamp NOT NULL DEFAULT '0000-00-00',
  hits integer(20) DEFAULT '0',
  loc_location integer(20) DEFAULT '0',
  reputation integer(20) NOT NULL DEFAULT '0',
  lockedby_user integer(20) NOT NULL DEFAULT '0',
  locktime timestamp NOT NULL DEFAULT '0',
  authoraccess char(4) NOT NULL DEFAULT 'iiii',
  groupaccess char(5) NOT NULL DEFAULT 'iiiii',
  otheraccess char(5) NOT NULL DEFAULT 'iiiii',
  guestaccess char(5) NOT NULL DEFAULT 'iiiii',
  dynamicauthor_permission integer(20) NOT NULL DEFAULT '-1',
  dynamicgroup_permission integer(20) NOT NULL DEFAULT '-1',
  dynamicother_permission integer(20) NOT NULL DEFAULT '-1',
  dynamicguest_permission integer(20) NOT NULL DEFAULT '-1',
  group_usergroup integer(20) NOT NULL DEFAULT '-1'
)},
        q{CREATE TABLE nodetype (
nodetype_id INTEGER PRIMARY KEY NOT NULL,
restrict_nodetype integer(20) DEFAULT '0',
extends_nodetype integer(20) DEFAULT '0',
restrictdupes integer(20) DEFAULT '0',
sqltable char(255),
grouptable char(40) DEFAULT '',
defaultauthoraccess char(4) NOT NULL DEFAULT 'iiii',
defaultgroupaccess char(5) NOT NULL DEFAULT 'iiiii',
defaultotheraccess char(5) NOT NULL DEFAULT 'iiiii',
defaultguestaccess char(5) NOT NULL DEFAULT 'iiiii',
defaultgroup_usergroup integer(20) NOT NULL DEFAULT '-1',
defaultauthor_permission integer(20) NOT NULL DEFAULT '-1',
defaultgroup_permission integer(20) NOT NULL DEFAULT '-1',
defaultother_permission integer(20) NOT NULL DEFAULT '-1',
defaultguest_permission integer(20) NOT NULL DEFAULT '-1',
maxrevisions integer(20) NOT NULL DEFAULT '-1',
canworkspace integer(20) NOT NULL DEFAULT '-1'
)},
        q{CREATE TABLE version (
  version_id INTEGER  PRIMARY KEY DEFAULT '0' NOT NULL,
  version INTEGER DEFAULT '1' NOT NULL
)}
    );

}

sub mysql_base_tables {

    return (
        q{CREATE TABLE node (
  node_id int(11) NOT NULL auto_increment,
  type_nodetype int(11) DEFAULT '0' NOT NULL,
  title char(240) DEFAULT '' NOT NULL,
  author_user int(11) DEFAULT '0' NOT NULL,
  createtime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  modified datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  hits int(11) DEFAULT '0',
  loc_location int(11) DEFAULT '0',
  reputation int(11) DEFAULT '0' NOT NULL,
  lockedby_user int(11) DEFAULT '0' NOT NULL,
  locktime datetime DEFAULT '0000-00-00 00:00:00' NOT NULL,
  authoraccess char(4) DEFAULT 'iiii' NOT NULL,
  groupaccess char(5) DEFAULT 'iiiii' NOT NULL,
  otheraccess char(5) DEFAULT 'iiiii' NOT NULL,
  guestaccess char(5) DEFAULT 'iiiii' NOT NULL,
  dynamicauthor_permission int(11) DEFAULT '-1' NOT NULL,
  dynamicgroup_permission int(11) DEFAULT '-1' NOT NULL,
  dynamicother_permission int(11) DEFAULT '-1' NOT NULL,
  dynamicguest_permission int(11) DEFAULT '-1' NOT NULL,
  group_usergroup int(11) DEFAULT '-1' NOT NULL,
  PRIMARY KEY (node_id),
  KEY title (title,type_nodetype),
  KEY author (author_user),
  KEY type (type_nodetype)
)},
        q{CREATE TABLE nodetype (
  nodetype_id int(11) DEFAULT '0' NOT NULL,
  restrict_nodetype int(11) DEFAULT '0',
  extends_nodetype int(11) DEFAULT '0',
  restrictdupes int(11) DEFAULT '0',
  sqltable char(255),
  grouptable char(40) DEFAULT '',
  defaultauthoraccess char(4) DEFAULT 'iiii' NOT NULL,
  defaultgroupaccess char(5) DEFAULT 'iiiii' NOT NULL,
  defaultotheraccess char(5) DEFAULT 'iiiii' NOT NULL,
  defaultguestaccess char(5) DEFAULT 'iiiii' NOT NULL,
  defaultgroup_usergroup int(11) DEFAULT '-1' NOT NULL,
  defaultauthor_permission int(11) DEFAULT '-1' NOT NULL,
  defaultgroup_permission int(11) DEFAULT '-1' NOT NULL,
  defaultother_permission int(11) DEFAULT '-1' NOT NULL,
  defaultguest_permission int(11) DEFAULT '-1' NOT NULL,
  maxrevisions int(11) DEFAULT '-1' NOT NULL,
  canworkspace int(11) DEFAULT '-1' NOT NULL,
  PRIMARY KEY (nodetype_id)
)},
        q{CREATE TABLE setting (
  setting_id int(11) DEFAULT '0' NOT NULL,
  vars text NOT NULL,
  PRIMARY KEY (setting_id)
)},
        q{CREATE TABLE version (
  version_id int(11) DEFAULT '0' NOT NULL,
  version int(11) DEFAULT '1' NOT NULL,
  PRIMARY KEY (version_id)
)}
      )

}

sub mysql_base_nodes {

    return (
q{INSERT INTO node VALUES (1,1,'nodetype',-1,'0000-00-00 00:00:00','0000-00-00 00:00:00',0,0,0,0,'0000-00-00 00:00:00','iiii','rwxdc','-----','-----',0,0,0,0,0)},
q{INSERT INTO node VALUES (2,1,'node',-1,'0000-00-00 00:00:00','0000-00-00 00:00:00',0,0,0,0,'0000-00-00 00:00:00','rwxd','-----','-----','-----',-1,-1,-1,-1,0)},
q{INSERT INTO node VALUES (3,1,'setting',-1,'0000-00-00 00:00:00','0000-00-00 00:00:00',0,0,0,0,'0000-00-00 00:00:00','rwxd','-----','-----','-----',0,0,0,0,0)},
q{INSERT INTO nodetype VALUES (1,0,2,1,'nodetype','','rwxd','rwxdc','-----','-----',0,0,0,0,0,-1,0)},
q{INSERT INTO nodetype VALUES (2,0,0,1,'','','rwxd','r----','-----','-----',0,0,0,0,0,1000,1)},
q{INSERT INTO nodetype VALUES (3,0,2,1,'setting','','rwxd','-----','-----','-----',0,0,0,0,0,-1,-1)},

      )

}

sub Pg_base_nodes {

    return (
q{INSERT INTO node VALUES (1,1,'nodetype',-1,'-infinity','-infinity',0,0,0,0, '-infinity','iiii','rwxdc','-----','-----',0,0,0,0,0)},
q{INSERT INTO node VALUES (2,1,'node',-1,'-infinity','-infinity',0,0,0,0,'-infinity','rwxd','-----','-----','-----',-1,-1,-1,-1,0)},
q{INSERT INTO node VALUES (3,1,'setting',-1,'-infinity','-infinity',0,0,0,0,'-infinity','rwxd','-----','-----','-----',0,0,0,0,0)},
q{INSERT INTO nodetype VALUES (1,0,2,1,'nodetype','','rwxd','rwxdc','-----','-----',0,0,0,0,0,-1,0)},
q{INSERT INTO nodetype VALUES (2,0,0,1,'','','rwxd','r----','-----','-----',0,0,0,0,0,1000,1)},
q{INSERT INTO nodetype VALUES (3,0,2,1,'setting','','rwxd','-----','-----','-----',0,0,0,0,0,-1,-1)},

      )

}

package Everything::Test::Ecore;

use Everything::NodeBase;
use Everything::Storage::Nodeball;
use Carp qw/confess cluck croak/;
use Test::More;
use base 'Test::Class';

use strict;
use warnings;

sub startup : Test( startup ) {
    my $self        = shift;
    my $stored_ball = Everything::Storage::Nodeball->new;
    $stored_ball->set_nodebase( $self->{nb} );
    $stored_ball->set_nodeball( $self->{nodeball} );

    $self->{ball} = $stored_ball;

    #    $self->install_basenodes; # base nodes always in test db
}

sub test_10_sql_tables : Test(1) {
    my $self = shift;

    my %expected_tables =
      map { $_ => 1 }
      qw/version mail image container node symlink nodemethod nodetype typeversion nodelet revision workspace htmlcode themesetting htmlpage nodegroup javascript setting document user links/;

    $self->{ball}->insert_sql_tables;
    my %actual_tables = map { $_ => 1 } $self->{nb}->{storage}->list_tables;

    is_deeply( \%actual_tables, \%expected_tables,
        '...testing all tables we expected are there.' )
      || $self->BAILOUT("Can't proceed without tables installed");

}

sub test_11_base_nodes : Test(3) {

    my $self = shift;

    my $nb = $self->{nb};

    my $ball  = $self->{ball};
    my $nodes = $nb->getNodeWhere( '', 'nodetype', 'node_id' );

    my @get_these = ();
    push @get_these, [ $$_{title}, $$_{type}{title} ] foreach @$nodes;

    my $select = sub {
        my $xmlnode  = shift;
        my $nodetype = $xmlnode->get_nodetype;
        my $title    = $xmlnode->get_title;
        foreach (@get_these) {
            if ( $title eq $_->[0] && $nodetype eq $_->[1] ) {
                return 1;
            }
        }

        return;
    };
    my $node_iterator = $ball->make_node_iterator($select);

    while ( my $xmlnode = $node_iterator->() ) {
        my $title = $xmlnode->get_title;
        my $type  = $xmlnode->get_nodetype;

        my $node = $nb->getNode( $title, $type );

        foreach ( @{ $xmlnode->get_attributes } ) {

            if ( $_->get_type eq 'literal_value' ) {
                $$node{ $_->get_name } = $_->get_content;
            }
            elsif ( $_->get_type eq 'noderef' ) {

                my ($ref_name) = split /,/, $_->get_type_nodetype;
                my $ref_node = $nb->getNode( $_->get_content, $ref_name );

                $$node{ $_->get_name } = $ref_node ? $ref_node->{node_id} : -1;
            }
        }

        ok( $node->update( -1, 'nomodify' ),
            "...base node, $$node{title}, has been updated" );
    }
    $nb->rebuildNodetypeModules();

}

sub test_20_nodetypes : Test(1) {

    my $self = shift;

    my $nb            = $self->{nb};
    my $nodetypes_dir = $self->{ball}->get_nodeball_dir . '/nodes/nodetype';

    $Everything::DB = $nb;
    my $errors;
    local *Everything::logErrors;
    *Everything::logErrors = sub { $errors = "@_"; };

    $self->{ball}->install_xml_nodetype_nodes;
    print "Fixing references...\n";
    $self->{ball}->fix_node_references(1);
    print "   - Done.\n";


    my %all_types =
      map { $_ => 1 } $self->{nb}->{storage}->fetch_all_nodetype_names;

    my %xml_types = ();
    my $iterator  = $self->{ball}->make_node_iterator(
        sub {
            my $xmlnode = shift;
            if ( $xmlnode->get_nodetype eq 'nodetype' ) {
                $xml_types{ $xmlnode->get_title } = 1;
                return 1;
            }
            return;
        }
    );
    while ( $iterator->() ) {
    }
    is_deeply( \%all_types, \%xml_types, '...28 nodetypes are installed.' );

}

sub test_30_install_nodes : Test(1) {

    my $self   = shift;
    my $errors = '';

    local *Everything::logErrors;
    *Everything::logErrors = sub { confess("@_") };

    $self->{ball}->install_xml_nodes(
        sub {
            my $xmlnode = shift;
            return 1 unless $xmlnode->get_nodetype eq 'nodetype';
            return;
        }
    );

    $self->{ball}->fix_node_references(1);
    my $nodes = $self->{nb}->selectNodeWhere();

    is( @$nodes, 273, '...should be 273 nodes installed.' );
}

sub test_40_verify_nodes : Test( 273 ) {
    my $self = shift;
    my $nb   = $self->{nb};

    $nb->resetNodeCache();

    my $ball          = $self->{ball};
    my $node_iterator = $ball->make_node_iterator;

    while ( my $xmlnode = $node_iterator->() ) {
        my $title = $xmlnode->get_title;
        my $type  = $xmlnode->get_nodetype;

        my $node = $nb->getNode( $title, $type );

        ok( $node, "...test existence of '$title', '$type'" );

    }

}

sub test_50_verify_nodes_attributes : Tests {
    my $self = shift;
    my $nb   = $self->{nb};

    my $ball          = $self->{ball};
    my $node_iterator = $ball->make_node_iterator;

    my $total_tests = 0;
    while ( my $xmlnode = $node_iterator->() ) {
        my $atts = $xmlnode->get_attributes;
	$total_tests += scalar(@$atts);

    }

    $self->num_tests($total_tests);

    ## now run attribute tests
    $node_iterator = $ball->make_node_iterator;

    while ( my $xmlnode = $node_iterator->() ) {
        my $atts = $xmlnode->get_attributes;

        my $node_title = $xmlnode->get_title;
        my $node_type  = $xmlnode->get_nodetype;

        my $node = $nb->getNode( $node_title, $node_type );

        foreach (@$atts) {
            my $att_name = $_->get_name;

            my $att_type = $_->get_type;

            if ( $att_type eq 'literal_value' ) {

                ## the line below makes undef an empty string to deal
                ## with the way database tables are created at the
                ## moment.
                my $content = defined $_->get_content ? $_->get_content : '';

                is( $node->{$att_name}, $content,
"...test node: '$node_title' of type '$node_type', attribute '$att_name'."
                );
            }
            else {

                my ($type_name) = split /,/, $_->get_type_nodetype;
                my $node_name = $_->get_content;

                my $wanted = $nb->getNode( $node_name, $type_name );

                is( $node->{$att_name}, $wanted->{node_id},
"... node '$node_title', attribute '$att_name' references '$$wanted{title}'."
                );

            }

        }

    }

}

sub test_60_verify_node_vars : Tests {
    my $self = shift;
    my $nb   = $self->{nb};

    my $ball = $self->{ball};

    my $vars_selector = sub { return 1 if @{ $_[0]->get_vars }; return; };

    my $node_iterator = $ball->make_node_iterator($vars_selector);

    my $total_vars = 0;
    while ( my $xmlnode = $node_iterator->() ) {
        my $vars = $xmlnode->get_vars;
        $total_vars += scalar(@$vars);

    }

    $self->num_tests($total_vars);

    ## now run attribute tests
    $node_iterator = $ball->make_node_iterator($vars_selector);

    while ( my $xmlnode = $node_iterator->() ) {
        my $vars = $xmlnode->get_vars;

        my $node_title = $xmlnode->get_title;
        my $node_type  = $xmlnode->get_nodetype;

        my $node    = $nb->getNode( $node_title, $node_type );
        my $db_vars = $node->getVars;

        foreach (@$vars) {
            my $var_name = $_->get_name;

            my $var_type = $_->get_type;

            if ( $var_type eq 'literal_value' ) {

                ## the line below makes undef an empty string to deal
                ## with the way database tables are created at the
                ## moment.
                my $content = defined $_->get_content ? $_->get_content : '';

                is( $db_vars->{$var_name}, $content,
"...test node: '$node_title' of type '$node_type', var '$var_name'."
                );
            }
            else {

                my ($type_name) = split /,/, $_->get_type_nodetype;
                my $node_name = $_->get_content;

                my $wanted = $nb->getNode( $node_name, $type_name );

                is( $db_vars->{$var_name}, $wanted->{node_id},
"... node '$node_title', var '$var_name' references '$$wanted{title}'."
                );

            }

        }

    }

}

sub test_70_verify_nodegroup_members : Tests {
    my $self = shift;
    my $nb   = $self->{nb};

    my $ball = $self->{ball};

    my $group_selector =
      sub { return 1 if @{ $_[0]->get_group_members }; return; };

    my $node_iterator = $ball->make_node_iterator($group_selector);

    my $total_members = 0;
    while ( my $xmlnode = $node_iterator->() ) {
        my $members = $xmlnode->get_group_members;
        $total_members += scalar(@$members);

    }

    $self->num_tests($total_members);

    ## now run attribute tests
    $node_iterator = $ball->make_node_iterator($group_selector);

    while ( my $xmlnode = $node_iterator->() ) {
        my $members = $xmlnode->get_group_members;

        my $node_title = $xmlnode->get_title;
        my $node_type  = $xmlnode->get_nodetype;

        my $node = $nb->getNode( $node_title, $node_type );
        my %db_members = map { $_ => 1 } @{ $node->selectGroupArray };

        foreach (@$members) {

            my ($type_name) = split /,/, $_->get_type_nodetype;
            my $node_name = $_->get_name;

            my $wanted = $nb->getNode( $node_name, $type_name );

            ok(
                $db_members{ $wanted->{node_id} },
                "... node '$node_title',contains group member '$$wanted{title}."
            );

        }

    }

}

1;
