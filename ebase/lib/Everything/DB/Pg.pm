package Everything::DB::Pg;

#############################################################################
#       Everything::DB::Pg
#               PostgreSQL database support.
#
#       Copyright 2002, 2006 Everything Development Inc.
#
#############################################################################

use strict;
use warnings;

use DBI;

use Moose;

extends 'Everything::DB';

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
	my ( $this, $dbname, $host, $user, $pass, $port ) = @_;

	my $connect_string = "DBI:Pg:dbname=$dbname;host=$host";
	$connect_string .= ";port=$port" if $port;

	$this->{dbh} =
		DBI->connect( $connect_string, $user, $pass )or die "Unable to get database connection!";
	$this->{dbh}->{ChopBlanks} = 1;

	
}

around nodetype_data_by_id => sub {

     my $orig = shift;
     my $self = shift;
     my $id = shift;

     return if not defined $id or $id =~ /\D/;
     return $self->$orig($id, @_);



};

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
	my ( $this, $table, $getHash ) = @_;
	my $field;
	my @fields;
	my $value;

	$getHash = 1 if ( not defined $getHash );
	$table ||= "node";

	my $DBTABLE ||= {};

	my $cursor = $this->{dbh}->column_info( undef, undef, $table, '%' );

	die $cursor->err if $cursor->err;
	$cursor->execute();

	die $DBI::errstr if $DBI::errstr;

	while ( my $field = $cursor->fetchrow_hashref )
	  {

	      # DBD::Pg seems to automatically quote some (but not
	      # all) column names.  This is a workaround.
	      $$field{COLUMN_NAME} =~ s/^"?(.*?)"?$/$1/;

	      # for backwards compatibility
	      $$field{Field} = $$field{COLUMN_NAME};

	      push @{ $DBTABLE->{Fields} }, $field;
	  }

	$$DBTABLE{Fields} ||= [];

	if ( not $getHash )
	{
		return map { $$_{Field} } @{ $$DBTABLE{Fields} };
	}
	else
	{
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
	my ( $this, $tableName ) = @_;
	my $cursor =
		$this->{dbh}->prepare(
"SELECT c.relname as \"Name\" FROM pg_class c WHERE c.relkind IN ('r', '') AND c.relname !~ '^pg_' ORDER BY 1"
		);
	my $table;

	$cursor->execute();
	while ( ($table) = $cursor->fetchrow() )
	{
		if ( $table eq $tableName )
		{
			$cursor->finish();
			return 1;
		}
	}

	$cursor->finish();

	return 0;
}

sub databaseExists {

    my ( $self, $database, $user, $password, $host, $port ) = @_;

    $host ||= 'localhost';
    $port ||= 5432;

    my $dbh;

    if ( ! ref $self || ! $self->{dbh} ) {
	$dbh = DBI->connect( "DBI:Pg:dbname=postgres;host=$host;port=$port", $user, $password );
	} else {

	    $dbh = $self->getDatabaseHandle

	}

    my $c = $dbh->prepare("select count(1) from pg_catalog.pg_database where datname = ?");

    $c->execute( $database );
    my ( $rv ) = $c->fetchrow;
    return $rv;

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
	my ( $this, $table ) = @_;
	my $tableid = $table . "_id";
	my $result;

	return -1 if ( $this->tableExists($table) );

	$result =
		$this->{dbh}->do( "create table \"$table\" ($tableid int4"
			. " DEFAULT '0' NOT NULL, PRIMARY KEY($tableid))" );

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
	my ( $this, $table ) = @_;

	return -1 if ( $this->tableExists($table) );

	my $dbh     = $this->getDatabaseHandle();
	my $tableid = $table . "_id";

	# fuzzie fixme: this code needs to be changed for each db, duh

	my $sql;
	$sql = <<SQLEND;
                create table \"$table\" (
                        $tableid int4 REFERENCES node(node_id) ON DELETE CASCADE,
                        rank int4 DEFAULT '0' NOT NULL,
                        node_id int4 REFERENCES node(node_id) ON DELETE CASCADE,
                        orderby int4 DEFAULT '0' NOT NULL,
                        PRIMARY KEY($tableid,rank)
                )
SQLEND

	return 1 if $dbh->do($sql);
	return 0;
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
	my ( $this, $table, $field ) = @_;
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
sub addFieldToTable {
    my ( $this, $table, $fieldname, $type, $primary, $default ) = @_;
    my $sql;

    return 0 if ( ( $table eq "" ) || ( $fieldname eq "" ) || ( $type eq "" ) );

    if (   ( ( not defined($default) ) || ( $default eq '' ) )
        && ( $type =~ /^int/i || $type =~ /(?:big)|(?:small)int/i ) )
    {
        $default = 0;
    }

    elsif ( ( not defined($default) ) && $type =~ /^text/i ) {

        # Text blobs cannot have default strings.  They need to be empty.
        $default = "";
    } elsif ( not defined $default ) {
	$default = '';
    }

    $sql = "alter table \"$table\" add $fieldname $type";
    $sql .= " default '$default' not null";

    $this->{dbh}->do($sql);

    if ($primary) {

        # This requires a little bit of work.  We need to figure out what
        # primary keys already exist, drop them, and then add them all
        # back in with the new key.
        my @fields = $this->getFieldsHash($table);
        my @prikeys;
        my $primaries;

        foreach my $field (@fields) {
            push @prikeys, $$field{Field} if ( $$field{Key} eq "PRI" );
        }

        $this->{dbh}->do("alter table \"$table\" drop primary key")
          if ( @prikeys > 0 );

        push @prikeys, $fieldname;    # add the new field to the primaries
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
	my ( $this, $table ) = @_;

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
	return 0 if ( $$this{transaction} );
	$$this{dbh}->begin_work;
	return $$this{transaction} = 1;
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
#               0 on error i.e. if a transaction isn't already in progress, 1 otherwise.
#
sub commitTransaction
{
	my ($this) = @_;
	return 0 unless ( $$this{transaction} );
	$$this{dbh}->{RaiseError} = 1;
	$$this{dbh}->commit;
	$$this{dbh}->{AutoCommit} = 1;
	$$this{transaction} = 0;
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
#               0 on error, no transaction to rollback.  1 on success.
#
sub rollbackTransaction
{
	my ($this) = @_;
	return 0 unless ( $$this{transaction} );
	$$this{dbh}->rollback;
	$$this{dbh}->{AutoCommit} = 1;
	$$this{transaction} = 0;
	return 1;
}

sub genLimitString
{
	my ( $this, $offset, $limit ) = @_;

	$offset ||= 0;

	return "LIMIT $limit OFFSET $offset";
}

sub genTableName
{
	my ( $this, $table ) = @_;

	return '"' . $table . '"';
}


sub lastValue
{
	my ( $this, $table, $field ) = @_;

	return $this->getDatabaseHandle()->selectrow_array("SELECT currval('${table}_${field}_seq')");
}

sub list_tables {

    my ($this) = @_;
    my $sth = $this->{dbh}->prepare("select c.relname FROM pg_catalog.pg_class c LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace WHERE c.relkind IN ('r','') AND n.nspname NOT IN ('pg_catalog', 'pg_toast') AND pg_catalog.pg_table_is_visible(c.oid)");

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

override _quoteData => sub {

    my $self = shift;
    my ($names, $values, $bound) = super;
    my @quoted_names = map { '"' . $_ .'"' } @$names;
    return \@quoted_names, $values, $bound;

};


=head2 C<get_create_table>

Returns the create table statements of the tables whose names were passed as arguments

Returns a list if there is more than one table or a string if there is only one.

=cut

### Here we build the create statement manually.  It should be OK with
### the the current everything.  However, it doesn't work if we start
### using other features, such as foreign key constraints.

## The code below has been copied from some php code found here
## http://www.phpbbstyles.com/viewtopic.php?p=69590&highlight= That
## code is a bit broken as it uses pg_relcheck, which is not current.
## CHECK constraints are now handled by pg_constraint.  Which is what
## we'd use if we were going to beef up this method.

sub get_create_table {

    my ( $self, @tables ) = @_;

    @tables = $self->list_tables unless @tables;
    my %table_def;
    my $dbh = $self->{dbh};

    foreach (@tables) {

        my $column_def = '';
        ## First get columns:

        my $sth = $dbh->prepare(
'SELECT a.attnum, a.attname AS field, t.typname as type, a.attlen AS length, a.atttypmod as lengthvar, a.attnotnull as notnull
        FROM  pg_type t, pg_class c,
        pg_attribute a

        WHERE c.relname = ?
            AND a.attnum > 0  
            AND a.attrelid = c.oid  
            AND a.atttypid = t.oid
        ORDER BY a.attnum'
        )                 || die $DBI::errstr;
        $sth->execute($_) || die $DBI::errstr;

        my @col_def;
        while ( my $result = $sth->fetchrow_hashref ) {

            push @col_def,
              {
                field     => $$result{'field'},
                data_type => $$result{'type'},
                notnull   => $$result{'notnull'},
                length    => $$result{'length'},
                lengthvar => $$result{'lengthvar'},
                attnum    => $$result{attnum}
              };

        }
        $table_def{$_} = \@col_def;

    }

    ### Now get default values someone who is better at SQL than I
    ### could do this in one statement with a proper use of LEFT JOIN
    ### or UNION or something clever

    my $sth = $dbh->prepare(
        "SELECT d.adsrc AS rowdefault  
            FROM pg_attrdef d, pg_class c  
            WHERE (c.relname = ? )  
                AND (c.oid = d.adrelid)  
                AND d.adnum = ? "
    ) || die $DBI::errstr;

    foreach my $table_name ( keys %table_def ) {
        foreach my $column ( @{ $table_def{$table_name} } ) {

            $sth->execute( $table_name, $column->{attnum} ) || die $DBI::errstr;

            while ( my $result = $sth->fetchrow_arrayref ) {
                $column->{default} = $$result[0];
            }

        }

    }

    my @statements;
    foreach my $table_name ( keys %table_def ) {
        my $statement = "CREATE TABLE \"$table_name\" (\n";

        my @col_defs;
        foreach my $col ( @{ $table_def{$table_name} } ) {

            my $col_name  = $col->{field};
            my $data_type = $col->{'data_type'};
            my $data_len  = $col->{'length'};
            my $default   = $col->{'default'};
            my $lengthvar = $col->{'lengthvar'};

            if ( $data_type eq 'bpchar' ) {
                $data_type = 'char(' . ( $lengthvar - 4 ) . ')';
            }

            if ( $data_type eq 'int8' ) {
                $data_type = 'bigint';
            }

            if ( $data_type eq 'int4' ) {
                $data_type = 'integer';
            }

            if ( $default && $default =~ /nextval/ ) {
                undef $default;
                $data_type = 'serial';
            }

            $default =~ s/::(.*)$// if $default;

            my $statement = "\t\"$col_name\" $data_type";
            $statement .= " DEFAULT $default" if $default;
            $statement .= ' NOT NULL'         if $col->{'notnull'};
            push @col_defs, $statement;
        }

        ## find keys

        my $sth = $dbh->prepare(
"SELECT ic.relname AS index_name, bc.relname AS tab_name, ta.attname AS column_name, i.indisunique AS unique_key, i.indisprimary AS primary_key  
        FROM pg_class bc, pg_class ic, pg_index i, pg_attribute ta, pg_attribute ia  
        WHERE (bc.oid = i.indrelid)  
            AND (ic.oid = i.indexrelid)  
            AND (ia.attrelid = i.indexrelid)  
            AND    (ta.attrelid = bc.oid)  
            AND (bc.relname = ?)  
            AND (ta.attrelid = i.indrelid)  
            AND (ta.attnum = i.indkey[ia.attnum-1])  
        ORDER BY index_name, tab_name, column_name"
        ) || die $DBI::errstr;

        $sth->execute($table_name);

        my %indices;
        while ( my $result = $sth->fetchrow_hashref ) {

            if ( $result->{primary_key} ) {
                push @col_defs, "\tPRIMARY KEY (\"$$result{column_name}\")";
            }
            else {
                if ( exists $indices{ $$result{index_name} } ) {
                    push @{ $indices{ $$result{index_name} }->{column_name} },
                      $$result{column_name};
                }
                else {
                    $indices{ $$result{index_name} } = {
                        unique => $$result{unique_key} ? ' UNIQUE' : '',
                        column_name => [ $$result{column_name} ],
                        table_name  => $$result{tab_name}
                    };
                }

            }
        }

        $statement .= join ",\n", @col_defs;
        $statement .= "\n);\n";
        push @statements, $statement;

        foreach ( keys %indices ) {
            my %index = %{ $indices{$_} };
            push @statements,
              "CREATE$index{unique} INDEX \"$_\" ON \"$index{table_name}\" ("
              . join( ', ', map { '"' . $_ . '"' } @{ $index{column_name} } )
              . ");\n";
        }

    }
    return $statements[0] if @statements == 1;
    return @statements;
}



sub create_database {

    my ($self, $db_name, $user, $password, $host, $port ) = @_;
    $host ||= 'localhost';
    $port ||= 5432;

    my $dbh = DBI->connect( "DBI:Pg:dbname=postgres;host=$host;port=$port",
        $user, $password )
      || die(
"$DBI::errstr,  Can't connect to Pg database."
      );


    $dbh->do( "CREATE DATABASE $db_name" );

    die($DBI::errstr) if $DBI::errstr;

    $self->{dbh} = DBI->connect( "DBI:Pg:dbname=$db_name;host=$host;port=$port", $user, $password );
    die($DBI::errstr) if $DBI::errstr;

    return $db_name;

}


=head2 drop_database

Drops the database.  Takes the database name, user, password, host and port as arguments.

=cut

sub drop_database {
    my ( $this, $dbname, $user, $password, $host, $port ) = @_;

    $port ||= 5432;

    $host ||=  'localhost';

    my $dbh;
    $dbh = DBI->connect(  "DBI:Pg:dbname=postgres;host=$host;port=$port",
        $user, $password  )
		or die "Unable to get database connection!";

    if ( ref $this ) {
	undef $this->{nb};
	$this->{dbh}->disconnect;
    }

    $dbh->do( "drop database $dbname" );
    die $DBI::errstr if $DBI::errstr;
    return 1;

}

sub grant_privileges {
    my ( $self, $dbname, $user, $password, $host, $port ) = @_;

    $port ||= 5432;

    $host ||=  'localhost';

    my $dbh = $self->{dbh};

    my $sth = $dbh->prepare("SELECT usename FROM pg_user WHERE usename = '$user'");

    die ( $DBI::errstr ) if $DBI::errstr;

    $sth->execute;

    die ( $DBI::errstr ) if $DBI::errstr;

    unless ( $sth->fetchrow ) {

	$dbh->do( "CREATE ROLE $user WITH LOGIN PASSWORD '$password'");
	die ( "Can't create user, $user, $DBI::errstr" ) if $DBI::errstr;
    }

    $dbh->do("GRANT ALL PRIVILEGES on DATABASE $dbname TO $user");
    die ( $DBI::errstr ) if $DBI::errstr;

    ## we reconnect so our new user has full privileges to the newly
    ## created tables, sequences, etc.
    $dbh = DBI->connect( "DBI:Pg:dbname=$dbname;host=$host;port=$port",
        $user, $password )
      || die(
"$DBI::errstr,  Can't connect to Pg database."
      );

    $self->{dbh} = $dbh;
}

after 'install_base_nodes' => sub {
    my $self = shift;

    ## ensure the node_id sequence is properly set
    $self->{dbh}->do("SELECT setval('node_node_id_seq', 3)")


};

sub base_tables {
    return (
        q{CREATE TABLE "setting" (
  "setting_id" serial NOT NULL,
  "vars" text default '',
  PRIMARY KEY ("setting_id")
)},
        q{CREATE TABLE "node" (
  "node_id" serial UNIQUE NOT NULL,
  "type_nodetype" bigint,
  "title" character(240),
  "author_user" bigint,
  "createtime" timestamp NOT NULL,
  "modified" timestamp,
  "loc_location" bigint,
  "lockedby_user" bigint,
  "locktime" timestamp,
  "authoraccess" character(4) DEFAULT 'iiii' NOT NULL,
  "groupaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "otheraccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "guestaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "dynamicauthor_permission" bigint,
  "dynamicgroup_permission" bigint,
  "dynamicother_permission" bigint,
  "dynamicguest_permission" bigint,
  "group_usergroup" bigint,
  PRIMARY KEY ("node_id")
)},
        q{ CREATE TABLE "node_statistics_type" (
           "type_name" varchar(255) NOT NULL,
           "description" text,
           "node_statistics_type_pk" bigserial UNIQUE NOT NULL,
          PRIMARY KEY ("node_statistics_type_pk")
)},
	q{ CREATE TABLE "node_statistics" (
           type bigint REFERENCES node_statistics_type(node_statistics_type_pk) ON DELETE RESTRICT,
           node bigint REFERENCES node(node_id) ON DELETE CASCADE,
           value bigint NOT NULL,
           PRIMARY KEY( type, node )
)},
        q{CREATE INDEX "title" on node ("title", "type_nodetype")},
        q{CREATE INDEX "author" on node ("author_user")},
        q{CREATE INDEX "type" on node ("type_nodetype")},
        q{CREATE TABLE "nodetype" (
  "nodetype_id" serial NOT NULL,
  "restrict_nodetype" bigint,
  "extends_nodetype" bigint,
  "restrictdupes" bigint,
  "sqltable" character(255),
  "grouptable" character(40),
  "defaultauthoraccess" character(4) DEFAULT 'iiii' NOT NULL,
  "defaultgroupaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "defaultotheraccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "defaultguestaccess" character(5) DEFAULT 'iiiii' NOT NULL,
  "defaultgroup_usergroup" bigint,
  "defaultauthor_permission" bigint,
  "defaultgroup_permission" bigint,
  "defaultother_permission" bigint,
  "defaultguest_permission" bigint,
  "maxrevisions" bigint,
  "canworkspace" bigint,
  PRIMARY KEY ("nodetype_id")
)},
        q{CREATE TABLE version (
  version_id INTEGER  PRIMARY KEY DEFAULT '0' NOT NULL,
  version INTEGER DEFAULT '1' NOT NULL
)},
q{CREATE TABLE "revision" (
  "node_id" bigint NOT NULL REFERENCES node(node_id) ON DELETE CASCADE,
  "inside_workspace" bigint DEFAULT '0' NOT NULL,
  "revision_id" bigint DEFAULT '0' NOT NULL,
  "xml" text NOT NULL,
  "tstamp" timestamp(6),
  PRIMARY KEY ("node_id", "inside_workspace", "revision_id")
)
},
q{CREATE TABLE "links" (
  "from_node" bigint NOT NULL REFERENCES node(node_id) ON DELETE RESTRICT,
  "to_node" bigint NOT NULL REFERENCES node(node_id) ON DELETE RESTRICT,
  "linktype" bigint DEFAULT '0' NOT NULL,
  "hits" bigint DEFAULT '0',
  "food" bigint DEFAULT '0',
  PRIMARY KEY ("from_node", "to_node", "linktype")
)
},
q{CREATE TABLE "typeversion" (
  "typeversion_id" bigint DEFAULT '0' NOT NULL,
  "version" bigint DEFAULT '0' NOT NULL,
  PRIMARY KEY ("typeversion_id")
)},
    );
}

sub base_nodes {

    return (
q{INSERT INTO node VALUES (1,1,'nodetype',-1,'-infinity','-infinity',0,0, '-infinity','iiii','rwxdc','-----','-----',0,0,0,0,0)},
q{INSERT INTO node VALUES (2,1,'node',-1,'-infinity','-infinity',0,0,'-infinity','rwxd','-----','-----','-----',-1,-1,-1,-1,0)},
q{INSERT INTO node VALUES (3,1,'setting',-1,'-infinity','-infinity',0,0,'-infinity','rwxd','-----','-----','-----',0,0,0,0,0)},
q{INSERT INTO nodetype VALUES (1,0,2,1,'nodetype','','rwxd','rwxdc','-----','-----',0,0,0,0,0,-1,0)},
q{INSERT INTO nodetype VALUES (2,0,0,1,'','','rwxd','r----','-----','-----',0,0,0,0,0,1000,1)},
q{INSERT INTO nodetype VALUES (3,0,2,1,'setting','','rwxd','-----','-----','-----',0,0,0,0,0,-1,-1)},
q{INSERT INTO node_statistics_type VALUES ('hits', 'A value that represents how many times a node has been accessed.')},
q{INSERT INTO node_statistics_type VALUES ('reputation', 'A value that represents the value of a node to the users.')},
      )

}

1;
