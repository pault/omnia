#!/usr/bin/perl

use Everything::NodeBase;
use Everything::Nodeball;
use Everything::Test::Ecore::Install;
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

my $tests = Everything::Test::Ecore::Install->new;

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
    push @failed, $_ + 1 unless $tests[$_];
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
