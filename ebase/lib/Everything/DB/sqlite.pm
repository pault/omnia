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

	my $DBTABLE = $this->{nb}->getNode( $table, 'dbtable' ) || {};

	unless ( exists $DBTABLE->{Fields} )
	{
		my $sth = $this->{dbh}->prepare_cached( "SELECT * FROM $table" );
		$sth->execute();

		my $href = $sth->fetchrow_hashref();
		$sth->finish();

		@{ $DBTABLE->{Fields} } = map { { Field => $_ } } keys %$href;
	}

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

	my ($result) = $sth->fetch();
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
		"create table $table ($tableid int4 DEFAULT '0' NOT NULL PRIMARY KEY");
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

	my $sql = <<"	SQLEND";
	create table $table (
		$tableid int4 DEFAULT '0' NOT NULL PRIMARY KEY,
		rank int4 DEFAULT '0' NOT NULL PRIMARY KEY,
		node_id int4 DEFAULT '0' NOT NULL,
		orderby int4 DEFAULT '0' NOT NULL,
	)
	SQLEND

	return $dbh->do($sql);
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

	return $this->{dbname} eq $database;
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

sub now { return time() }

sub timediff { "$_[1] - $_[2]" }

1;
