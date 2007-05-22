=head1	Everything::DB::mysql

MySQL database support.

Copyright 2002 - 2003, 2006 Everything Development Inc.

=cut

package Everything::DB::mysql;

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

	$this->{dbh} = DBI->connect( "DBI:mysql:$dbname:$host", $user, $pass )
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

	unless ( exists $$DBTABLE{Fields} )
	{
		my $cursor = $this->{dbh}->prepare_cached("show columns from $table");
		$cursor->execute();

		while ( my $field = $cursor->fetchrow_hashref )
		{
			push @{ $DBTABLE->{Fields} }, $field;
		}
	}

	return @{ $$DBTABLE{Fields} } if $getHash;
	return map { $$_{Field} } @{ $$DBTABLE{Fields} };
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
	my $cursor = $this->{dbh}->prepare("show tables");

	$cursor->execute();
	while ( my ($table) = $cursor->fetchrow() )
	{
		if ( $table eq $tableName )
		{
			$cursor->finish();
			return 1;
		}
	}

	return 0;
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
	my $tableid = $table . "_id";

	return -1 if $this->tableExists($table);

	return $this->{dbh}
		->do( "create table $table ($tableid int4 DEFAULT '0' NOT NULL,"
			. "PRIMARY KEY($tableid))" );
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
		$tableid int4 DEFAULT '0' NOT NULL auto_increment,
		rank int4 DEFAULT '0' NOT NULL,
		node_id int4 DEFAULT '0' NOT NULL,
		orderby int4 DEFAULT '0' NOT NULL,
		PRIMARY KEY($tableid,rank)
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

	return $this->{dbh}->do("alter table $table drop $field");
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

		# This requires a little bit of work.  We need to figure out what
		# primary keys already exist, drop them, and then add them all back in
		# with the new key.

		my @fields = $this->getFieldsHash($table);
		my @prikeys;

		foreach my $field (@fields)
		{
			push @prikeys, $$field{Field} if $$field{Key} eq 'PRI';
		}

		$this->{dbh}->do("alter table $table drop primary key") if @prikeys;

		# add the new field to the primaries
		push @prikeys, $fieldname;
		my $primaries = join ',', @prikeys;
		$this->{dbh}->do("alter table $table add primary key($primaries)");
	}

	return 1;
}

=head2 C<startTransaction>

Starts a database transaction.

Returns 0 if a transaction is already in progress, 1 otherwise.

=cut

sub startTransaction
{
	return 1;
}

=head2 commitTransaction

Commits a database transaction.

Returns 1 if a transaction isn't already in progress, 0 otherwise.

=cut

sub commitTransaction
{
	return 1;
}

=head2 C<rollbackTransaction>

Rolls back a database transaction. This isn't guaranteed to work,
due to lack of implementation in certain DBMs. Don't depend on it.

Returns 1 if a transaction isn't already in progress, 0 otherwise.

=cut

sub rollbackTransaction
{
	return 1;
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
	my $sth = $this->{dbh}->prepare('show databases');
	$sth->execute();

	while ( my ($dbname) = $sth->fetchrow() )
	{
		return 1 if $dbname eq $database;
	}
}

sub list_tables
{
	my ($this) = @_;
	my $sth = $this->{dbh}->prepare('show tables');

	$sth->execute();

	my @tables;
	while ( my ($table) = $sth->fetchrow() )
	{
		push @tables, $table;
	}

	return @tables;
}

sub now { return 'now()' }

sub timediff { "$_[1] - $_[2]" }


=head2 C<lastValue>

Returns the last sequence/auto_increment value inserted into the
database.  This will return undef on error.

=over 4

=item * $table

the table (this MUST be the table used in the last query)

=item * $field

the auto_increment field

=back

=cut

sub lastValue
{
	my ( $this, $table, $field ) = @_;

	## NB: this list of undefs is required by DBI.pm for mysql. I
	## believe this is a feature.
	return $this->getDatabaseHandle()->last_insert_id(undef, undef, undef, undef);
}



=head2 C<get_create_table>

Returns the create table statements of the tables whose names were passed as arguments

Returns a list if there is more than one table or a string if there is only one.

=cut

sub get_create_table {

    my ( $self, @tables ) = @_;

    @tables = $self->list_tables unless @tables;
    my @statements = ();
    my $dbh = $self->{dbh};

    foreach ( @tables ) {
	my $sth = $dbh->prepare("show create table $_") || die $DBI::errstr;
	$sth->execute;
	my $result = $sth->fetchrow_hashref;
	push @statements, $result->{'Create Table'};
    }
    return $statements[0] if @statements == 1;
    return @statements;
}

1;
