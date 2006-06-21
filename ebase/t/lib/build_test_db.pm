#! perl

# XXX: this file depends on the format of tables/*.sql
# run it through SQL::Translator if and when it changes!

use strict;
use warnings;

use DBI;
use File::Spec::Functions 'catfile';

my $db_file = catfile(qw( t ebase.db ));
unlink $db_file;

my $dbh = DBI->connect( "dbi:SQLite:dbname=$db_file", '', '' );

my @tables = split /\n--\n/, <<END_TABLES;
CREATE TABLE node (
  node_id INTEGER PRIMARY KEY NOT NULL,
  type_nodetype int(11) NOT NULL DEFAULT '0',
  title char(240) NOT NULL DEFAULT '',
  author_user int(11) NOT NULL DEFAULT '0',
  createtime datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  modified datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  hits int(11) DEFAULT '0',
  loc_location int(11) DEFAULT '0',
  reputation int(11) NOT NULL DEFAULT '0',
  lockedby_user int(11) NOT NULL DEFAULT '0',
  locktime datetime NOT NULL DEFAULT '0000-00-00 00:00:00',
  authoraccess char(4) NOT NULL DEFAULT 'iiii',
  groupaccess char(5) NOT NULL DEFAULT 'iiiii',
  otheraccess char(5) NOT NULL DEFAULT 'iiiii',
  guestaccess char(5) NOT NULL DEFAULT 'iiiii',
  dynamicauthor_permission int(11) NOT NULL DEFAULT '-1',
  dynamicgroup_permission int(11) NOT NULL DEFAULT '-1',
  dynamicother_permission int(11) NOT NULL DEFAULT '-1',
  dynamicguest_permission int(11) NOT NULL DEFAULT '-1',
  group_usergroup int(11) NOT NULL DEFAULT '-1'
);
--
CREATE TABLE nodetype (
  nodetype_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  restrict_nodetype int(11) DEFAULT '0',
  extends_nodetype int(11) DEFAULT '0',
  restrictdupes int(11) DEFAULT '0',
  sqltable char(255),
  grouptable char(40) DEFAULT '',
  defaultauthoraccess char(4) NOT NULL DEFAULT 'iiii',
  defaultgroupaccess char(5) NOT NULL DEFAULT 'iiiii',
  defaultotheraccess char(5) NOT NULL DEFAULT 'iiiii',
  defaultguestaccess char(5) NOT NULL DEFAULT 'iiiii',
  defaultgroup_usergroup int(11) NOT NULL DEFAULT '-1',
  defaultauthor_permission int(11) NOT NULL DEFAULT '-1',
  defaultgroup_permission int(11) NOT NULL DEFAULT '-1',
  defaultother_permission int(11) NOT NULL DEFAULT '-1',
  defaultguest_permission int(11) NOT NULL DEFAULT '-1',
  maxrevisions int(11) NOT NULL DEFAULT '-1',
  canworkspace int(11) NOT NULL DEFAULT '-1'
);
--
CREATE TABLE setting (
  setting_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  vars text(65535) NOT NULL
);
--
CREATE TABLE version (
  version_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  version int(11) NOT NULL DEFAULT '1'
);
--
CREATE INDEX title_node on node (title, type_nodetype);
--
CREATE INDEX author_node on node (author_user);
--
CREATE INDEX type_node on node (type_nodetype);
END_TABLES

my $nodes = do {
	local $/; local @ARGV = catfile(qw( tables basenodes.in )); <> 
};

for my $statement (@tables, split /\n/, $nodes )
{
	next unless $statement =~ /\S/;
	$dbh->do( $statement );
}

$dbh->disconnect();

1;
