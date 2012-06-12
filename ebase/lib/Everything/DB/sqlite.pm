=head1	Everything::DB::sqlite

SQLite database support.

Copyright 2006 Everything Development Inc.

=cut

package Everything::DB::sqlite;

use strict;
use warnings;

use DBI;
use base 'Everything::DB';

=head2 C<databaseConnect>

Connect to the database.

=over 4

=item * dbname

the database name

=item * $host

the hostname of the database server

=item * $user

the username to use to connect

=item * $pass

the password to use to connect

=back

This will throw an exception if the connection fails.

=cut

sub databaseConnect
{
	my ( $this, $dbname, $host, $user, $pass ) = @_;

	$this->{dbname} = $dbname;
	$this->{dbh}    = DBI->connect( "dbi:SQLite:dbname=$dbname", $user, $pass )
		or die "Unable to get database connection!";

}

=head2 purge_node_data

Removes all the data related to a node.  Passed a node object as its argument.

=cut

sub purge_node_data {

    my ( $self, $node ) = @_;

    $self->sqlDelete( 'node_statistics', 'node = ?', [ $node->getId ] );

    return $self->SUPER::purge_node_data( $node );

}

=head2 C<getFieldsHash>

Given a table name, returns the names of fields.  If C<$getHash> is true, it
will be an array of hashrefs of the fields.

=over 4

=item * $table

the name of the table to get fields for

=item * $getHash

Set to 1 if you would also like the entire field hash instead of just the field
name. (By default, true.)

=back

=cut

sub getFieldsHash
{
	my ( $this, $table, $getHash ) = @_;

	$getHash = 1 unless defined $getHash;
	$table ||= "node";

	my $DBTABLE = {};
	$DBTABLE->{Fields} = [];

	my $sth = $this->{dbh}->prepare( "PRAGMA table_info($table)" );
	$sth->execute();

	while ( my $table_desc = $sth->fetchrow_arrayref()) {
	    push @{ $DBTABLE->{Fields} }, { Field => $$table_desc[1] };
	}
	$sth->finish();

	return @{ $DBTABLE->{Fields} } if $getHash;
	return map { $_->{Field} } @{ $DBTABLE->{Fields} };
}

sub lastValue
{
	my $self = shift;
	return $self->{dbh}->func( 'last_insert_rowid' );
}

=head2 C<tableExists>

Check to see if a table of the given name exists in this database.  Returns 1
if it exists, 0 if not.

=over 4

=item * $tableName

The table to check.

=back

=cut

sub tableExists
{
	my ( $this, $tableName ) = @_;
	my $sth = $this->{dbh}->prepare(
		"SELECT count(*) FROM sqlite_master WHERE type='table' AND name=?"
	);

	$sth->execute( $tableName );

	my ($result) = $sth->fetchrow_array();

	return $result;
}

=head2 C<createNodeTable>

Create a new database table for a node, if it does not already exist.  This
creates a new table with one field for the id of the node in the form of
tablename_id.

Returns 1 if successful, 0 if failure, -1 if table already exists.

=over 4

=item * $tableName

the name of the table to create

=back

=cut

sub createNodeTable
{
	my ( $this, $table ) = @_;
	my $tableid = $table . '_id';

	return -1 if $this->tableExists($table);

	return $this->{dbh}->do(
		"create table $table ($tableid int4 PRIMARY KEY)");
}

=head2 C<createGroupTable>

Creates a new group table if it does not already exist.  Returns 1 if
successful, 0 if failure, or -1 if table already exists.

=over 4

=item * $tableName

the name of the table to create

=back

=cut

sub createGroupTable
{
	my ( $this, $table ) = @_;

	return -1 if $this->tableExists($table);

	my $dbh     = $this->getDatabaseHandle();
	my $tableid = $table . "_id";

	my @sql = ();
	## sqlite doesn't implement foreign keys but we have it here for good form!
	$sql[0] = <<"	SQLEND";
	create table $table (
		$tableid int4 NOT NULL,
		rank int4 DEFAULT 0,
		node_id int4 NOT NULL REFERENCES node( node_id ) ON DELETE CASCADE,
		orderby int4,
                PRIMARY KEY( $tableid , rank )
	)
	SQLEND

### Currently sqlite seg faults when it raises an abort.  Also the
### installation model can't code with referential integrity.  Until
### the installation model is fixed these must remain commented out.


#   	$sql[1] =<<SQLEND;
#   	CREATE TRIGGER fki_${table}_node_id
#   	  BEFORE INSERT ON $table
#   	  FOR EACH ROW BEGIN 
#   	    SELECT CASE
#   	      WHEN ((SELECT node.node_id FROM node WHERE  node.node_id = NEW.node_id) IS NULL)
#                THEN RAISE(ABORT, 'Insert violates foreign key constraint')
#   	     END;
#   	END;
# SQLEND


#  	$sql[2] =<<"	SQLEND";
#  	CREATE TRIGGER fku_${table}_node_id
#  	  BEFORE UPDATE ON $table
#  	  FOR EACH ROW BEGIN 
#  	    SELECT CASE
#  	      WHEN ((SELECT node_id FROM node WHERE  node.node_id = NEW.node_id) IS NULL)
#  	      THEN RAISE(ABORT, 'update on table "$table" violates foreign key constraint "fki_${table}"')
#  	     END;
#  	END;
#  	SQLEND
 
#  	$sql[3] =<<"	SQLEND";
#  	CREATE TRIGGER fkd_${table}_node_id
#  	  BEFORE DELETE ON node
#  	    FOR EACH ROW BEGIN 
#  	      DELETE from $table WHERE ${table}.node_id = OLD.node_id;
#  	END;

#  	SQLEND

	eval {
	  foreach ( @sql ) {
	      return unless $dbh->do( $_ );
	  }
      };
	  return 0 if $@;
	return 1;
}

=head2 C<dropFieldFromTable>

Removes a field from the given table.  Returns 1 if successful, 0 on failure.

=over 4

=item * $table

the table to remove the field from

=item * $field

the field to drop

=back

=cut

sub dropFieldFromTable
{
	my ( $this, $table, $field ) = @_;

	die "XXX: Unimplemented; fix soon\n";
=cut

BEGIN TRANSACTION;
CREATE TABLE t1_backup(a,b);
INSERT INTO t1_backup SELECT a,b FROM t1;
DROP TABLE t1;
INSERT INTO t1 SELECT a,b FROM t1_backup;
ALTER TABLE t1_backup RENAME TO t1;
COMMIT;

=cut
}

=head2 C<addFieldToTable>

Adds a new field to an existing database table.  Returns 1 if successful, 0 on
failure.

=over 4

=item * $table

the table to add the new field to.

=item * $fieldname

the name of the field to add

=item * $type

the type of the field (ie int(11), char(32), etc)

=item * $primary

(optional) is this field a primary key?  Defaults to no.

=item * $default

(optional) the default value of the field.

=back

=cut

sub addFieldToTable
{
	my ( $this, $table, $fieldname, $type, $primary, $default ) = @_;

	return 0 if ( ( $table eq '' ) || ( $fieldname eq '' ) || ( $type eq '' ) );

	# Text blobs cannot have default strings.  They need to be empty.
	$default = '' if ( $type =~ /^text/i );

	unless ( defined $default )
	{
		$default = $type =~ /^int/i ? 0 : '';
	}

	my $sql =
		  qq|alter table $table add $fieldname $type default "$default" |
		. "not null";

	$this->{dbh}->do($sql);

	if ($primary)
	{
		# This requires a little bit of work.  Recreate the table instead.
		die "XXX: Unimplemented primary key editing\n";
	}

	return 1;
}

=head2 C<startTransaction>

Starts a database transaction.

Returns 0 if a transaction is already in progress, 1 otherwise.

=cut

sub startTransaction
{
	my $self = shift;
	$self->getDatabaseHandle->begin_work();
}

=head2 commitTransaction

Commits a database transaction.

Returns 1 if a transaction isn't already in progress, 0 otherwise.

=cut

sub commitTransaction
{
	my $self = shift;
	$self->getDatabaseHandle->commit();
}

=head2 C<rollbackTransaction>

Rolls back a database transaction. This isn't guaranteed to work,
due to lack of implementation in certain DBMs. Don't depend on it.

Returns 1 if a transaction isn't already in progress, 0 otherwise.

=cut

sub rollbackTransaction
{
	my $self = shift;
	$self->getDatabaseHandle->rollback();
}

sub genLimitString
{
	my ( $this, $offset, $limit ) = @_;

	$offset ||= 0;

	return "LIMIT $offset, $limit";
}

sub genTableName
{
	my ( $this, $table ) = @_;

	return $table;
}

=head2 C<databaseExists>

Purpose:
	See if a database exists

Takes:
	C<$database>, the name of the database for which to check

Returns:
	true or false, if the database exists

=cut

sub databaseExists
{
	my ( $this, $database ) = @_;

	return -e $database;
}

sub list_tables
{
	my ($this) = @_;
	my $sth = $this->{dbh}->prepare(
		'SELECT name FROM sqlite_master WHERE type="table"' );

	$sth->execute();

	my @tables;

	while ( my ($table) = $sth->fetchrow() )
	{
		push @tables, $table;
	}

	return @tables;
}

=head2 C<get_create_table>

Returns the create table statements of the tables whose names were passed as arguments

Returns a list if there is more than one table or a string if there is only one.

=cut

sub get_create_table {

    my ( $self, @tables ) = @_;

    my @statements = ();
    my $dbh = $self->{dbh};

    my $where = " where type = 'table'";
    $where .= " and " . join ' or ', map { "name = '$_'" } @tables if @tables;
    my $sth = $dbh->prepare( "select sql from sqlite_master" . $where) || die $DBI::errstr;
    $sth->execute;
    while (my $sql = $sth->fetchrow_arrayref) {
	push @statements, @$sql;
    }

    return $statements[0] if @statements == 1;
    return @statements;
}

sub now { return "datetime('now')" }

sub timediff { "$_[1] - $_[2]" }

sub create_user {

    1;

}

sub create_database {
	my ( $this, $dbname ) = @_;

	$this->{dbname} = $dbname;
	$this->{dbh}    = DBI->connect( "dbi:SQLite:dbname=$dbname" )
		or die "Unable to get database connection!";


}

sub drop_database {
    my ( $this, $dbname ) = @_;

    unlink $dbname;

}

=head2 C<grant_privileges>

Does nothing for sqlite. Returns true.

=cut

sub grant_privileges {

    1;

}

=head2 C<base_tables>

Returns a list of SQL statements necessary to insert the base tables into a databse.

=cut


sub base_tables {
    return (
        q{CREATE TABLE setting (
  setting_id INTEGER PRIMARY KEY NOT NULL,
  vars text DEFAULT ''
)},
        q{CREATE TABLE node (
  node_id INTEGER PRIMARY KEY,
  type_nodetype integer(20),
  title char(240),
  author_user integer(20),
  createtime timestamp NOT NULL,
  modified timestamp,
  loc_location integer(20),
  lockedby_user integer(20),
  locktime timestamp,
  authoraccess char(4) NOT NULL DEFAULT 'iiii',
  groupaccess char(5) NOT NULL DEFAULT 'iiiii',
  otheraccess char(5) NOT NULL DEFAULT 'iiiii',
  guestaccess char(5) NOT NULL DEFAULT 'iiiii',
  dynamicauthor_permission integer(20),
  dynamicgroup_permission integer(20),
  dynamicother_permission integer(20),
  dynamicguest_permission integer(20),
  group_usergroup integer(20)
)},
        q{CREATE TABLE nodetype (
nodetype_id INTEGER PRIMARY KEY NOT NULL,
restrict_nodetype integer(20),
extends_nodetype integer(20),
restrictdupes integer(20),
sqltable char(255),
grouptable char(40),
defaultauthoraccess char(4) NOT NULL DEFAULT 'iiii',
defaultgroupaccess char(5) NOT NULL DEFAULT 'iiiii',
defaultotheraccess char(5) NOT NULL DEFAULT 'iiiii',
defaultguestaccess char(5) NOT NULL DEFAULT 'iiiii',
defaultgroup_usergroup integer(20),
defaultauthor_permission integer(20),
defaultgroup_permission integer(20),
defaultother_permission integer(20),
defaultguest_permission integer(20),
maxrevisions integer(20),
canworkspace integer(20)
)},
q{CREATE TABLE sql_tables (
  type varchar(20) NOT NULL REFERENCES sql_table_type(name) ON DELETE RESTRICT,
  name char(40),
  nodetype INTEGER NOT NULL REFERENCES nodetype(nodetype_id) ON DELETE CASCADE,
  PRIMARY KEY (name, nodetype)

)},
q{CREATE TABLE sql_table_type (
   name varchar(20) PRIMARY KEY NOT NULL,
   description text
)},
q{CREATE TABLE sql_command_type (
 name varchar(40) NOT NULL PRIMARY KEY,
 description text
)},
q{CREATE TABLE sql_commands (
  type varchar (40) NOT NULL REFERENCES sql_command_type(name) ON DELETE RESTRICT,
    nodetype INTEGER NOT NULL REFERENCES nodetype(nodetype_id) ON DELETE CASCADE,
  command text,
  PRIMARY KEY (type, nodetype)
)},
        q{CREATE TABLE version (
  version_id INTEGER  PRIMARY KEY DEFAULT '0' NOT NULL,
  version INTEGER DEFAULT '1' NOT NULL
)},
        q{ CREATE TABLE node_statistics_type (
           type_name varchar(255) NOT NULL,
           description text,
           node_statistics_type_pk INTEGER PRIMARY KEY NOT NULL
)},
	q{ CREATE TABLE node_statistics (
           type INT REFERENCES node_statistics_type(node_statistics_type_pk) ON DELETE RESTRICT,
           node int(11) NOT NULL REFERENCES node(node_id) ON DELETE CASCADE,
           value bigint NOT NULL,
           PRIMARY KEY( type, node )
)},
q{CREATE TABLE revision (
  node_id integer(20) NOT NULL REFERENCES node(node_id) ON DELETE CASCADE,
  inside_workspace integer(20) NOT NULL DEFAULT '0',
  revision_id integer(20) NOT NULL DEFAULT '0',
  xml text NOT NULL,
  tstamp timestamp,
  PRIMARY KEY (node_id, inside_workspace, revision_id)
)},
q{CREATE TABLE links (
  from_node integer(20) NOT NULL REFERENCES node(node_id) ON DELETE RESTRICT,
  to_node integer(20) NOT NULL  REFERENCES node(node_id) ON DELETE RESTRICT,
  linktype integer(20) NOT NULL DEFAULT '0',
  hits integer(20) DEFAULT '0',
  food integer(20) DEFAULT '0',
  PRIMARY KEY (from_node, to_node, linktype)
)},
q{CREATE TABLE typeversion (
  typeversion_id INTEGER PRIMARY KEY NOT NULL DEFAULT '0',
  version integer(20) NOT NULL DEFAULT '0'
)},
    );

}

1;
