package Everything::NodeBase::Pg;

#############################################################################
#       Everything::NodeBase::Pg
#               Postgresql database support.  
#
#       Copyright 2002 Everything Development Inc.
#       Format: tabs = 4 spaces
#
#############################################################################

use strict;
use DBI;
use Everything::NodeBase::Database;

use vars qw($VERSION @ISA @EXPORT);

@ISA = qw(Everything::NodeBase::Database);

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
sub databaseConnect {
	my ($this, $dbname, $host, $user, $pass) = @_;

        $this->{dbh} = DBI->connect("DBI:Pg:dbname=$dbname;host=$host", $user, $pass);
        $this->{dbh}->{ChopBlanks} = 1;

	die "Unable to get database connection!" unless($this->{dbh});
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

	return $this->{dbh}->do("SELECT currval(\'$table" . "_" . $field . "_seq\')")->fetchrow();
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
        my $field;
        my @fields;
        my $value; 
        
        $getHash = 1 if(not defined $getHash);
        $table ||= "node";

        my $DBTABLE = $this->getNode($table, 'dbtable');
        $DBTABLE ||= {};
        unless  (exists $$DBTABLE{Fields}) {
                my $cursor = $this->{dbh}->prepare_cached("SELECT a.attname AS \"Field\" FROM pg_class c, pg_attribute a, pg_type t WHERE c.relname = '$table' AND a.attnum > 0 AND a.attrelid = c.oid AND a.atttypid = t.oid ORDER BY a.attnum");

                $cursor->execute;
                while ($field = $cursor->fetchrow_hashref)
                {
                        push @fields, $field;
                }
                $cursor->finish();
                $$DBTABLE{Fields} = \@fields;
        }

	if (not $getHash) {
                return map { $$_{Field} } @{ $$DBTABLE{Fields} };
        } else {
		return @{ $$DBTABLE{Fields} };
        }
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
        my $cursor = $this->{dbh}->prepare("SELECT c.relname as \"Name\" FROM pg_class c WHERE c.relkind IN ('r', '') AND c.relname !~ '^pg_' ORDER BY 1");
        my $table;

        $cursor->execute();
        while(($table) = $cursor->fetchrow())
        {
                if($table eq $tableName)
                {
                        $cursor->finish();
                        return 1;
                }
        }

        $cursor->finish();

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
        my $result;
        
        return -1 if($this->tableExists($table));

        $result = $this->{dbh}->do("create table \"$table\" ($tableid int4" . " DEFAULT '0' NOT NULL, PRIMARY KEY($tableid))");

        return $result;
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

        return -1 if($this->tableExists($table));
                
        my $dbh = $this->getDatabaseHandle();
        my $tableid = $table . "_id";

        # fuzzie fixme: this code needs to be changed for each db, duh

        my $sql;
        $sql = <<SQLEND;
                create table \"$table\" (
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
        my $sql;

        $sql = "alter table \"$table\" drop $field";

        return $this->{dbh}->do($sql);
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
        my $sql;

        return 0 if(($table eq "") || ($fieldname eq "") || ($type eq ""));

    if(not defined $default)
        {
                if($type =~ /^int/i)
                {
                        $default = 0;
                }
                else
                {   
                        $default = "";
                }
        }
        elsif($type =~ /^text/i)
        {
                # Text blobs cannot have default strings.  They need to be empty.
                $default = "";
        }
         
        $sql = "alter table \"$table\" add $fieldname $type";
        $sql .= " default \"$default\" not null";

        $this->{dbh}->do($sql);

        if($primary)
        {
                # This requires a little bit of work.  We need to figure out what
                # primary keys already exist, drop them, and then add them all   
                # back in with the new key.
                my @fields = $this->getFieldsHash($table);
                my @prikeys;
                my $primaries;
                my $field;

                foreach $field (@fields)
                {
                        push @prikeys, $$field{Field} if($$field{Key} eq "PRI");
                }

                $this->{dbh}->do("alter table \"$table\" drop primary key") if(@prikeys > 0);

                push @prikeys, $fieldname; # add the new field to the primaries
                $primaries = join ',', @prikeys;
                $this->{dbh}->do("alter table \"$table\" add primary key($primaries)");
        }

        return 1;
}

#############################################################################
#       Sub
#               internalDropTable
#
#       Purpose
#               Drop (delete) a table from the database. Called by dropNodeTable.
#
#       Parameters
#               $table - the name of the table to drop.
#
#       Returns
#               1 if successful, 0 otherwise.
#
sub internalDropTable
{
        my ($this, $table) = @_;

        return $this->{dbh}->do("drop table \"$table\"");
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
	my ($this) = @_;
	return 0 if ($$this{transaction});
	$$this{dbh}->{AutoCommit} = 0;
	$$this{transaction} = 1;
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
	my ($this) = @_;
	return 1 unless ($$this{transaction});
	$$this{dbh}->commit;
	$$this{dbh}->{AutoCommit} = 1;
	$$this{transaction} = 0;
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
	my ($this) = @_;
	return 1 unless ($$this{transaction});
	$$this{dbh}->rollback;
	$$this{dbh}->{AutoCommit} = 1;
	$$this{transaction} = 0;
}

sub genLimitString
{
	my ($this, $offset, $limit) = @_;

	$offset ||= 0;

	return "LIMIT $limit, $offset";
}