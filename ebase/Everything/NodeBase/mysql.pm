package Everything::NodeBase::mysql;

#############################################################################
#       Everything::NodeBase::mysql
#               Mysql database support.  
#
#       Copyright 2002 Everything Development Inc.
#       Format: tabs = 4 spaces
#
#############################################################################

use strict;
use DBI;
use Everything::NodeBase;

use vars qw($VERSION @ISA @EXPORT);

@ISA = qw(Everything::NodeBase);

#############################################################################
#	Sub
#		databaseConnect
#
#	Purpose
#		Connect to the database.
#
#	Parameters
#		dbname - the database name
#		host - the hostname of the database server
#		user - the username to use to connect
#		pass - the password to use to connect
#
sub databaseConnect
{
	my ($this, $dbname, $host, $user, $pass) = @_;

	$this->{dbh} = DBI->connect("DBI:mysql:$dbname:$host", $user, $pass)
		or die "Unable to get database connection!";
}

#############################################################################
#       Sub
#               lastValue
#
#       Purpose
#               Return the last sequence/auto_increment value inserted into
#               the database.
#
#       Parameters
#               table - the table (this MUST be the table used in the last query)
#               field - the auto_increment field
#
#       Returns
#               The last sequence/auto_increment value inserted into the
#               database by this process/connection. undef if error.
#
sub lastValue
{
	my ($this, $table, $field) = @_;

	return $this->sqlSelect("LAST_INSERT_ID()");
}

#############################################################################
#   Sub
#       getFieldsHash
#
#   Purpose
#       Given a table name, returns a list of the fields or a hash.
#
#   Parameters
#       $table - the name of the table to get fields for
#       $getHash - set to 1 if you would also like the entire field hash
#           instead of just the field name. (set to 1 by default)
#
#   Returns
#       Array of field names, if getHash is 1, it will be an array of
#       hashrefs of the fields.
#
sub getFieldsHash
{
	my ($this, $table, $getHash) = @_;

	$getHash = 1 unless defined $getHash;
	$table ||= "node";

	my $DBTABLE = $this->getNode($table, 'dbtable') || {};

	unless (exists $$DBTABLE{Fields}) {
		my $cursor = $this->{dbh}->prepare_cached("show columns from $table");
		$cursor->execute();

		while (my $field = $cursor->fetchrow_hashref)
		{
			push @{ $DBTABLE->{Fields} }, $field;
		}
	}

	return @{ $$DBTABLE{Fields} } if $getHash;
	return map { $$_{Field} } @{ $$DBTABLE{Fields} };
}

#############################################################################
#       Sub
#               tableExists
#
#       Purpose
#               Check to see if a table of the given name exists in this database.
#
#       Parameters
#               $tableName - the table to check for.
#
#       Returns
#               1 if it exists, 0 if not.
#
sub tableExists
{
	my ($this, $tableName) = @_;
	my $cursor = $this->{dbh}->prepare("show tables");

	$cursor->execute();
	while(my ($table) = $cursor->fetchrow())
	{
		if($table eq $tableName)
		{
			$cursor->finish();
			return 1;
		}
	}

	return 0;
}

#############################################################################
#       Sub
#               createNodeTable
#
#       Purpose
#               Create a new database table for a node, if it does not already
#               exist.  This creates a new table with one field for the id of 
#               the node in the form of tablename_id.
#
#       Parameters
#               $tableName - the name of the table to create
#
#       Returns
#               1 if successful, 0 if failure, -1 if it already exists.
#
sub createNodeTable
{
	my ($this, $table) = @_;
	my $tableid = $table . "_id";
        
	return -1 if $this->tableExists($table);

	return $this->{dbh}->do(
		"create table $table ($tableid int4 DEFAULT '0' NOT NULL," .
		"PRIMARY KEY($tableid))");
}

#############################################################################
#       Sub
#               createGroupTable
#
#       Purpose
#               Creates a new group table if it does not already exist.
#
#       Returns
#               1 if successful, 0 if failure, -1 if it already exists.
#               
sub createGroupTable
{
	my ($this, $table) = @_;

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

#############################################################################
#       Sub
#               dropFieldFromTable
#
#       Purpose
#               Remove a field from the given table.
#
#       Parameters
#               $table - the table to remove the field from
#               $field - the field to drop
#
#       Returns
#               1 if successful, 0 if failure
#
sub dropFieldFromTable
{
	my ($this, $table, $field) = @_;

	return $this->{dbh}->do( "alter table $table drop $field" );
}

#############################################################################
#       Sub
#               addFieldToTable
#
#       Purpose
#               Add a new field to an existing database table.
#
#       Parameters
#               $table - the table to add the new field to.
#               $fieldname - the name of the field to add  
#               $type - the type of the field (ie int(11), char(32), etc)
#               $primary - (optional) is this field a primary key?  Defaults to no.
#               $default - (optional) the default value of the field.
#
#       Returns
#               1 if successful, 0 if failure.
#
sub addFieldToTable
{
	my ($this, $table, $fieldname, $type, $primary, $default) = @_;

	return 0 if (($table eq '') || ($fieldname eq '') || ($type eq ''));

	# Text blobs cannot have default strings.  They need to be empty.
	$default = '' if($type =~ /^text/i);

	unless (defined $default)
	{
		$default = $type =~ /^int/i ? 0 : '';
	}
  
	my $sql = qq|alter table $table add $fieldname $type default "$default" | .
	 	"not null";

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

#############################################################################
#       Sub
#               startTransaction
#
#       Purpose
#               Start a database transaction.
#
#       Parameters
#               None.
#
#       Returns
#               0 if a transaction is already in progress, 1 otherwise.
#
sub startTransaction
{
	return 1;
}

#############################################################################
#       Sub
#               commitTransaction
#
#       Purpose
#               Commit a database transaction.
#
#       Parameters
#               None.
#
#       Returns
#               1 if a transaction isn't already in progress, 0 otherwise.
#
sub commitTransaction
{
	return 1;
}

#############################################################################
#       Sub
#               rollbackTransaction
#
#       Purpose
#               Rollback a database transaction. This isn't guaranteed to work,
#		due to lack of implementation in certain DBMs. Don't depend on it.
#
#       Parameters
#               None.
#
#       Returns
#               1 if a transaction isn't already in progress, 0 otherwise.
#
sub rollbackTransaction
{
	return 1;
}

sub genLimitString
{
	my ($this, $offset, $limit) = @_;

	$offset ||= 0;

	return "LIMIT $offset, $limit";
}

sub genTableName
{
	my ($this, $table) = @_;

	return $table;
}
