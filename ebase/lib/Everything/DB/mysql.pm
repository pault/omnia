=head1	Everything::DB::mysql

MySQL database support.

Copyright 2002 - 2003, 2006 Everything Development Inc.

=cut

package Everything::DB::mysql;

use strict;
use warnings;

use DBI;

use Moose;
extends 'Everything::DB';

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

	my $DBTABLE = {};

	my $cursor = $this->{dbh}->column_info( undef, undef, $table, '%' );
	
	die $cursor->err if $cursor->err;
	$cursor->execute();

	die $DBI::errstr if $DBI::errstr;

	while ( my $field = $cursor->fetchrow_hashref )
	  {
	      # for backwards compatibility
	      $$field{Field} = $$field{COLUMN_NAME};

	      push @{ $DBTABLE->{Fields} }, $field;
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
		$tableid int4,
		rank int4 DEFAULT '0' NOT NULL,
		node_id int4,
		orderby int4 DEFAULT '0' NOT NULL,
                FOREIGN KEY (node_id) REFERENCES node(node_id) ON DELETE CASCADE,
                FOREIGN KEY ($tableid) REFERENCES node(node_id) ON DELETE CASCADE,

		PRIMARY KEY($tableid,rank)
	) ENGINE=INNODB
	SQLEND

	return 1 if $dbh->do($sql);
        return 0;
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
	my $self = shift;
	$self->getDatabaseHandle->begin_work;
}

=head2 commitTransaction

Commits a database transaction.

Returns 1 if a transaction isn't already in progress, 0 otherwise.

=cut

sub commitTransaction
{
	my $self = shift;
	$self->getDatabaseHandle->commit;

}

=head2 C<rollbackTransaction>

Rolls back a database transaction. This isn't guaranteed to work,
due to lack of implementation in certain DBMs. Don't depend on it.

Returns 1 if a transaction isn't already in progress, 0 otherwise.

=cut

sub rollbackTransaction
{
	my $self = shift;
	$self->getDatabaseHandle->rollback;
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
	my ( $this, $database, $user, $password, $host, $port ) = @_;

	my $dbh;

	if ( ! ref $this || ! $this->{dbh} ) {
	    $dbh = DBI->connect( "DBI:mysql:database=mysql;host=$host;port=$port", $user, $password );
	} else {

	    $dbh = $this->getDatabaseHandle

	}

	my $sth = $dbh->prepare('show databases');
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

sub create_database {

    my ($self, $db_name, $user, $password, $host, $port ) = @_;
    $host ||= 'localhost';
    $port ||= 3306;

    my $drh = DBI->install_driver('mysql');
    my $rc  =
      $drh->func( 'createdb', $db_name, $host, $user, $password, 'admin' );
    die($DBI::errstr) if $DBI::errstr;

    $self->{dbh} = DBI->connect( "DBI:mysql:database=$db_name;host=$host;port=$port", $user, $password );
    die($DBI::errstr) if $DBI::errstr;

    return $db_name;

}

=head2 drop_database

Drops the database.  Takes the following arguments: the database name, user, password, host and port.

=cut

sub drop_database {
    my ( $this, $dbname, $user, $password, $host, $port ) = @_;

    $host ||= '';
    $port ||= '';

    my $dbh;
    if ( ! ref $this || ! $this->{dbh} ) {
	$dbh = DBI->connect( "DBI:mysql:$dbname:$host", $user, $password )
		or die "Unable to get database connection!";
    } else {
	$dbh = $this->getDatabaseHandle;
    }

    $dbh->do( "drop database $dbname" );

    if ( $DBI::errstr ) {
	die $DBI::errstr;
	return 0;
    }

    return 1;

}

sub grant_privileges {
    my ( $self, $dbname, $user, $password, $host ) = @_;

    $host ||=  'localhost';

    $self->{dbh}->do("GRANT ALL PRIVILEGES on ${dbname}.* TO '$user'\@'$host' IDENTIFIED BY '$password'");

    die ( $DBI::errstr ) if $DBI::errstr;

}


sub base_tables {

    return (
        q{CREATE TABLE node (
  node_id int(11) NOT NULL auto_increment,
  type_nodetype int(11),
  title char(240),
  author_user int(11),
  createtime datetime,
  modified datetime,
  loc_location int(11),
  lockedby_user int(11),
  locktime datetime,
  authoraccess char(4) DEFAULT 'iiii' NOT NULL,
  groupaccess char(5) DEFAULT 'iiiii' NOT NULL,
  otheraccess char(5) DEFAULT 'iiiii' NOT NULL,
  guestaccess char(5) DEFAULT 'iiiii' NOT NULL,
  dynamicauthor_permission int(11),
  dynamicgroup_permission int(11),
  dynamicother_permission int(11),
  dynamicguest_permission int(11),
  group_usergroup int(11),
  PRIMARY KEY (node_id),
  KEY title (title,type_nodetype),
  KEY author (author_user),
  KEY type (type_nodetype)
) ENGINE=INNODB},

        q{CREATE TABLE nodetype (
  nodetype_id int(11),
  restrict_nodetype int(11),
  extends_nodetype int(11),
  restrictdupes int(11),
  sqltable char(255),
  grouptable char(40),
  defaultauthoraccess char(4) DEFAULT 'iiii' NOT NULL,
  defaultgroupaccess char(5) DEFAULT 'iiiii' NOT NULL,
  defaultotheraccess char(5) DEFAULT 'iiiii' NOT NULL,
  defaultguestaccess char(5) DEFAULT 'iiiii' NOT NULL,
  defaultgroup_usergroup int(11),
  defaultauthor_permission int(11),
  defaultgroup_permission int(11),
  defaultother_permission int(11),
  defaultguest_permission int(11),
  maxrevisions int(11),
  canworkspace int(11),
  PRIMARY KEY (nodetype_id)
) ENGINE=INNODB },
        q{CREATE TABLE setting (
  setting_id int(11) DEFAULT '0' NOT NULL,
  vars text NOT NULL,
  PRIMARY KEY (setting_id)
) ENGINE=INNODB },
        q{CREATE TABLE version (
  version_id int(11) DEFAULT '0' NOT NULL,
  version int(11) DEFAULT '1' NOT NULL,
  PRIMARY KEY (version_id)
) ENGINE=INNODB},
        q{ CREATE TABLE node_statistics_type (
           type_name varchar(255) NOT NULL,
           description text,
           node_statistics_type_pk INT NOT NULL AUTO_INCREMENT,
          PRIMARY KEY (node_statistics_type_pk)
)  ENGINE=INNODB},
	q{ CREATE TABLE node_statistics (
           type INT NOT NULL,
           node int(11) NOT NULL,
           value bigint NOT NULL,
           FOREIGN KEY (type) REFERENCES node_statistics_type(node_statistics_type_pk) ON DELETE RESTRICT,
           FOREIGN KEY(node) REFERENCES node(node_id) ON DELETE CASCADE,
           PRIMARY KEY( type, node )
) ENGINE=INNODB},
q{ CREATE TABLE revision (
  node_id int(11) NOT NULL,
  inside_workspace int(11) DEFAULT '0' NOT NULL,
  revision_id int(11) DEFAULT '0' NOT NULL,
  xml text NOT NULL,
  tstamp timestamp(14),
  FOREIGN KEY (node_id) REFERENCES node(node_id) ON DELETE CASCADE, 
  PRIMARY KEY (node_id,inside_workspace,revision_id)
) ENGINE=INNODB},

q{CREATE TABLE links (
  from_node int(11) NOT NULL,
  to_node int(11) NOT NULL,
  linktype int(11),
  hits int(11),
  food int(11),
  FOREIGN KEY (from_node) REFERENCES node(node_id) ON DELETE RESTRICT,
  FOREIGN KEY (to_node) REFERENCES node(node_id) ON DELETE RESTRICT,
  PRIMARY KEY (from_node,to_node,linktype)
)},
q{CREATE TABLE typeversion (
  typeversion_id int(11) DEFAULT '0' NOT NULL,
  version int(11) DEFAULT '0' NOT NULL,
  PRIMARY KEY (typeversion_id)
)},

      )

}

1;
