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
use SUPER;
use base 'Everything::DB';

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
	my ( $this, $dbname, $host, $user, $pass ) = @_;

	$this->{dbh} =
		DBI->connect( "DBI:Pg:dbname=$dbname;host=$host", $user, $pass )or die "Unable to get database connection!";
	$this->{dbh}->{ChopBlanks} = 1;

	
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
	my ( $this, $table, $getHash ) = @_;
	my $field;
	my @fields;
	my $value;

	$getHash = 1 if ( not defined $getHash );
	$table ||= "node";

	my $DBTABLE = $this->{nb}->getNode( $table, 'dbtable' );
	$DBTABLE ||= {};

	unless ( exists $$DBTABLE{Fields} )
	{

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
"SELECT c.relname as \"Name\" FROM pg_class c WHERE c.relkind IN ('r', 'v', '') AND c.relname !~ '^pg_' ORDER BY 1"
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
                        $tableid int4 REFERENCES node_basic(node_id) ON DELETE CASCADE,
                        rank int4 DEFAULT '0' NOT NULL,
                        node_id int4 REFERENCES node_basic(node_id) ON DELETE CASCADE,
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

=head2 insert_node_permissions_string

Inserts a permission string for a node.

Takes two arguments:

=over

=item 

 the node object to be inserted

=item

 the id of the node object to be inserted

=back



=cut

sub insert_node_permissions_string {

    my ( $this, $node, $node_id ) = @_;

    # permission strings only have four user types ...
    foreach my $usertype ( qw/author group other guest / ) {
	my $perms = $node->{ $usertype . 'access' };
	next unless $perms;

	my %perms;
	# .... and five permission types;
	@perms{ qw/ read write execute delete create/ } =
	  split ( //, $perms );

	delete $perms{create} if $usertype eq 'author';

	foreach my $permtype ( keys %perms ) {

	    my $behaviour;
	    if ( $perms{$permtype} eq '-' ) {
		$behaviour = 'disable';
	    } elsif ( $perms{$permtype} eq 'i' ) {
		$behaviour = 'inherit';
	    } else {
		$behaviour = 'enable';
	    }



	    my $dbh = $this->getDatabaseHandle;

	    my $st = $dbh->prepare( "INSERT INTO node_access ( node_id, user_type, permission_type, permission_behaviour )
SELECT
?,
user_type.user_type_pk,
permission_type.permission_type_pk,
permission_behaviour.permission_behaviour_pk
FROM user_type, permission_type, permission_behaviour
WHERE permission_type.permission = ?
AND   user_type.usertype = ?
AND   permission_behaviour.behaviour = ?" );


	    die $DBI::errstr if $DBI::errstr;
	    $st->execute( $node_id, $permtype, $usertype, $behaviour);

	    die $DBI::errstr if $DBI::errstr;
	}

    }

}



 sub insert_basic_node_data {
     my ( $this, $node, $user_id ) = @_;

     # node_basic table
     $this->sqlInsert( 'node_basic', { -createtime => $this->now, type_nodetype => $node->get_type->getId } );

     my $node_id = $this->lastValue ('node_basic', 'node_id');

     my $dbh = $this->getDatabaseHandle;

     $this->sqlInsert( "node_title", { node_id => $node_id, title => $node->get_title } ) if defined $node->get_title;

     # node relations
     # author_user, loc_location, group_usergroup

     $dbh->do( "SELECT insert_node_relation( $node_id, $node->get_author_user, 'author_user' " ) if defined $node->get_author_user;

     $dbh->do( "SELECT insert_node_relation( $node_id, $node->get_loc_location, 'loc_location' " ) if defined $node->get_loc_location;

     $dbh->do( "SELECT insert_node_relation( $node_id, $node->get_group_usergroup, 'group_usergroup' " ) if defined $node->get_group_usergroup;

     # Dynamic permissions
     #  dynamicauthor_permission,
     # dynamicgroup_permission, dynamicother_permission,
     # dynamicguest_permission, group_usergroup,

     foreach my $usertype (qw/author group other guest / ) {
	 my $perm = eval "\$node->get_dynamic${usertype}_permission";
	 if ( $perm ) {
	     my $st = $dbh->prepare("SELECT insert_dynamic_permission( ?, ?, ?, )" );
	     die $DBI::errstr if $DBI::errstr;
	     $st->execute( $node_id, $perm, $usertype );
	     die $DBI::errstr if $DBI::errstr;
	 }
     }

     #   authoraccess
     #   groupaccess
     #   otheraccess
     #   guestaccess

     $this->insert_node_permissions_string( $node, $node_id );

     # hits
     if ( defined $node->get_hits ) {
	 my $st = $dbh->prepare( "INSERT INTO node_statistics_hits (node_id, hits) VALUES (?, ? )");
	 $st->execute( $node_id, $node->get_hits );
	 die $DBI::errstr if $DBI::errstr;
     }

     #   reputation

     if ( defined $node->get_reputation ) {
	 my $st = $dbh->prepare( "INSERT INTO node_statistics_reputation (node_id, reputation) VALUES (?, ? )");
	 $st->execute( $node_id, $node->get_hits );
	 die $DBI::errstr if $DBI::errstr;
     }


     #   lockedby_user
     #   locktime

     if ( defined $node->get_lockedby_user ) {
	 my $st = $dbh->prepare( "INSERT INTO node_lock (node_id, locktime, lockedby_user ) VALUES (?, now(), ? )");
	 $st->execute( $node_id, $node->get_lockedby_user );
	 die $DBI::errstr if $DBI::errstr;
     }

     return $node_id;
}

sub lastValue
{
	my ( $this, $table, $field ) = @_;

	$table = 'node_basic' if $table eq 'node';
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

sub _quoteData {

    my $self = shift;
    my ($names, $values, $bound) = $self->SUPER( @_ );
    my @quoted_names = map { '"' . $_ .'"' } @$names;
    return \@quoted_names, $values, $bound;

}


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


    $dbh = DBI->connect( "DBI:Pg:dbname=$db_name;host=$host;port=$port", $user, $password );

    $dbh->do( q{ CREATE LANGUAGE plpgsql } );

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
	undef $this->{dbh};
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

sub install_base_nodes {
    my $self = shift;

    $self->SUPER;

    ## ensure the node_id sequence is properly set
    $self->{dbh}->do("SELECT setval('node_basic_node_id_seq', 3)")


}

my %sql = (
	   nodetype => { insert =>

sub {
    my ( $this, $node, $node_id ) = @_;

    my $dbh = $this->getDatabaseHandle;

    if ( $$node{restrict_nodetype} ) {
	my $st = $dbh->prepare('SELECT insert_node_relation( ?, ?, ?) ');
	$st->execute( $node_id, $$node{restrict_nodetype}, 'restrict_nodetype' );
    }

    if ( $$node{extends_nodetype} ) {
	my $st = $dbh->prepare('SELECT insert_node_relation( ?, ?, ?) ');
	$st->execute( $node_id, $$node{extends_nodetype}, 'extends_nodetype' );
    }


    if (defined $$node{restrictdupes} ) {

	my $behaviour;
	if ( $$node{restrictdupes} == 1) {
	    $behaviour = 'enable';
	} elsif ( $$node{restrictdupes} == 0 ) {
	    $behaviour = 'disable';
	} elsif ( $$node{restrictdupes} == -1 ) {
	    $behaviour = 'inherit';
	}
	my $st = $dbh->prepare('INSERT INTO node_authorisation ( node_id, permission_type, permission_behaviour )
   SELECT
    ?
    permission_type.permission_type_pk,
    permission_behaviour.permission_behaviour_pk
    FROM permission_type, permission_behaviour
    WHERE permission_type.permission = ?
    AND   permission_behaviour.behaviour = ?');
	$st->execute( $node_id, 'restrictdupes', $behaviour );

    }



    if ( $$node{sqltable} ) {
	my $st = $dbh->prepare('SELECT insert_sqltable_data( ? ,?, ?)');
	$st->execute( $$node{sqltable}, 'attributetable', $node_id );

    }


    if ( $$node{grouptable} ) {
	my $st = $dbh->prepare('SELECT insert_sqltable_data(?, ?, ? )');
	$st->execute( $$node{grouptable}, 'grouptable', $node_id );

    }


    for (qw/defaultauthor defaultgroup defaultother defaultguest/) {
	my $st = $dbh->prepare('SELECT insert_permissions( ?, ?, ? )');
	$st->execute( $node_id, $_, $$node{ $_ . 'access' } );

    }

    if ( $$node{defaultgroup_usergroup} ) {
	my $st = $dbh->prepare('SELECT insert_node_relation( ?, ?, ?) ');
	$st->execute( $node_id, $$node{defaultgroup_usergroup}, 'defaultgroup_usergroup' );
    }

    for ( qw/defaultauthor defaultgroup defaultother defaultguest/ ) {

	my $st = $dbh->prepare('  SELECT insert_dynamic_permission (?, ?, ? )');
	$st->execute( $node_id, $$node{ $_ . '_permission' }, $_ );
    }



    if ( defined $$node{maxrevisions} ) {
	my $st = $dbh->prepare('INSERT INTO nodebase_node_revisions (node_id, maxrevisions) VALUES (?, ? )' );
	$st->execute( $node_id, $$node{maxrevisions} );
    }


    if (defined $$node{canworkspace} ) {

	my $behaviour;
	if ( $$node{canworkspace} == 1) {
	    $behaviour = 'enable';
	} elsif ( $$node{canworkspace} == 0 ) {
	    $behaviour = 'disable';
	} elsif ( $$node{canworkspace} == -1 ) {
	    $behaviour = 'inherit';
	}
	my $st = $dbh->prepare('INSERT INTO node_authorisation ( node_id, permission_type, permission_behaviour )
   SELECT
    ?
    permission_type.permission_type_pk,
    permission_behaviour.permission_behaviour_pk
    FROM permission_type, permission_behaviour
    WHERE permission_type.permission = ?
    AND   permission_behaviour.behaviour = ?');
	$st->execute( $node_id, 'canworkspace', $behaviour );

    }

}
}

);

sub custom_sql {
    my ( $this, $node, $op ) = @_;
return;
    return $sql{$node->get_type->get_title}->{$op};

}

sub base_tables {
    return (
        q{CREATE TABLE "setting" (
  "setting_id" serial NOT NULL,
  "vars" text default '',
  PRIMARY KEY ("setting_id")
)},
q{
CREATE TABLE "node_relation_type" (
   name varchar(125) UNIQUE NOT NULL,
   description text,
   node_relation_type_pk serial,
   PRIMARY KEY ( "node_relation_type_pk" )
)
},
q{ CREATE INDEX index_node_relation_type ON node_relation_type ( name ) },

q{
 CREATE AGGREGATE textcat_all(
      basetype    = text,
      sfunc       = textcat,
      stype       = text,
      initcond    = ''
  );
},

q{

CREATE TABLE "node_basic" (
node_id  bigserial UNIQUE NOT NULL,
type_nodetype bigint,
createtime timestamp NOT NULL,
PRIMARY KEY (node_id)
)
},
q{ CREATE TABLE "node_relationship" (
   node bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
   hasa_node bigint REFERENCES node_basic(node_id) ON DELETE RESTRICT,
   relation_type int REFERENCES node_relation_type( node_relation_type_pk) ON DELETE RESTRICT,
   PRIMARY KEY ("node", "hasa_node", "relation_type")
)
},

#### sqltable_type - the type of table node attribute or group
q{CREATE TABLE "sqltable_type" (
  sqltable_type varchar(255) NOT NULL,
  description varchar(255),
  sqltable_type_pk serial,
  PRIMARY KEY ( "sqltable_type_pk" )
)
},

#### the sql tables to join on
q{CREATE TABLE "sqltable" (
    sqltable_name varchar(255) NOT NULL UNIQUE,
    type int REFERENCES sqltable_type(sqltable_type_pk) ON DELETE RESTRICT,
    sqltable_pk bigserial NOT NULL,
    PRIMARY KEY ( sqltable_pk )
)
},
q{
CREATE TABLE "node_sqltable" (
     sqltable bigint REFERENCES sqltable(sqltable_pk),
     nodetype_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
     node_sqltable_pk serial NOT NULL,
     UNIQUE (sqltable, nodetype_id),
     PRIMARY KEY ( node_sqltable_pk )
)
},
#### a nodetype attribute that restricts the members of a nodegroup to
#### a certain nodetype
q{ CREATE TABLE "nodegroup_restrict_type"(
   group_nodetype_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
   only_nodetype bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
   PRIMARY KEY( group_nodetype_id, only_nodetype )
)
},
### to store restricted dupes
q{
CREATE TABLE "nodebase_restrictdupes" (
     nodetype_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
     PRIMARY KEY (nodetype_id)
)
},

q{
CREATE TABLE "nodebase_node_workspace" (
     node_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
     enable boolean NOT NULL,
     PRIMARY KEY (node_id)
)
},
q{
CREATE TABLE "nodebase_node_revisions" (
     node_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
     maxrevisions int DEFAULT 0 NOT NULL,
     PRIMARY KEY (node_id)
)
},

q{

CREATE TABLE "node_modified" (
modified timestamp,
node_id bigint NOT NULL REFERENCES node_basic(node_id) ON DELETE CASCADE,
PRIMARY KEY (node_id)
)

},

q{

CREATE TABLE "node_title" (
title varchar(240),
node_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
PRIMARY KEY (node_id)
)

},

q{

CREATE TABLE "node_statistics_hits" (
hits bigint NOT NULL DEFAULT 0,
node_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
PRIMARY KEY (node_id)

)

},

q{

CREATE TABLE "node_location" (
loc_location bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
node_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
PRIMARY KEY (node_id)
)

},
q{

CREATE TABLE "node_statistics_reputation" (
reputation bigint NOT NULL DEFAULT 0,
node_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
PRIMARY KEY (node_id)
)

},

q{ CREATE TABLE "node_lock" (
locktime timestamp NOT NULL,
lockedby_user bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
node_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
PRIMARY KEY (node_id)
)
},
q{ CREATE TABLE "user_type" (
    user_type_pk serial NOT NULL,
    usertype varchar(32) NOT NULL,
    description varchar(255),
    PRIMARY KEY ("user_type_pk")
)
},
q{
   CREATE TABLE "permission_type" (
   permission_type_pk serial NOT NULL,
   permission  varchar(127) NOT NULL,
   description varchar(255),
   PRIMARY KEY("permission_type_pk")
)
},
q{
   CREATE TABLE "permission_behaviour" (
   permission_behaviour_pk serial NOT NULL,
   behaviour  varchar(10) NOT NULL,
   description varchar(255),
   PRIMARY KEY ("permission_behaviour_pk")
)
},
q{
CREATE TABLE "node_authorisation" (
permission_type int REFERENCES permission_type(permission_type_pk) ON DELETE RESTRICT NOT NULL,
permission_behaviour int REFERENCES permission_behaviour(permission_behaviour_pk) ON DELETE RESTRICT NOT NULL,
node_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
PRIMARY KEY (permission_type, node_id, permission_behaviour)
)
},
q{
CREATE TABLE "node_access" (
user_type int REFERENCES user_type(user_type_pk) ON DELETE RESTRICT NOT NULL,
permission_type int REFERENCES permission_type(permission_type_pk) ON DELETE RESTRICT NOT NULL,
permission_behaviour int REFERENCES permission_behaviour(permission_behaviour_pk) ON DELETE RESTRICT NOT NULL,
node_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
PRIMARY KEY (user_type, permission_type, node_id, permission_behaviour)
)
},
q{
CREATE TABLE "node_dynamicpermission" (
type int REFERENCES user_type (user_type_pk) ON DELETE RESTRICT,
permission bigint REFERENCES node_basic(node_id) ON DELETE RESTRICT,
node_id bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
PRIMARY KEY (type, node_id)
)
},
q{
CREATE TABLE "node_relationship_usertype" (

   node bigint REFERENCES node_basic(node_id) ON DELETE CASCADE,
   with_node bigint REFERENCES node_basic(node_id) ON DELETE RESTRICT,
   relation_type int REFERENCES node_relation_type( node_relation_type_pk) ON DELETE RESTRICT,
   user_type int REFERENCES user_type(user_type_pk) ON DELETE RESTRICT,
   PRIMARY KEY ("node", "with_node", "relation_type", "user_type")

)
},

q{
CREATE FUNCTION dynamicpermission ( bigint, text ) RETURNS bigint AS $$

SELECT permission FROM node_dynamicpermission WHERE type = ( SELECT user_type.user_type_pk FROM user_type WHERE user_type.usertype = $2) AND node_id = $1; 

$$ LANGUAGE SQL;
},

q{
CREATE OR REPLACE FUNCTION nodepermissions(bigint, varchar) RETURNS text AS $$

SELECT CASE ( SELECT permission_behaviour.behaviour from node_access, user_type, permission_type, permission_behaviour where permission_type.permission = 'read' AND node_access.node_id = $1 AND user_type.usertype = $2 AND node_access.user_type = user_type.user_type_pk AND node_access.permission_behaviour = permission_behaviour.permission_behaviour_pk  AND node_access.permission_type = permission_type.permission_type_pk) WHEN 'enable' THEN 'r' WHEN 'disable' THEN '-' WHEN 'inherit' THEN 'i' END
||
CASE (  SELECT permission_behaviour.behaviour from node_access, user_type, permission_type, permission_behaviour where permission_type.permission = 'write' AND node_access.node_id = $1 AND user_type.usertype = $2 AND node_access.user_type = user_type.user_type_pk AND node_access.permission_behaviour = permission_behaviour.permission_behaviour_pk  AND node_access.permission_type = permission_type.permission_type_pk)  WHEN 'enable' THEN 'w' WHEN 'disable' THEN '-' WHEN 'inherit' THEN 'i' END
||
CASE ( SELECT permission_behaviour.behaviour from node_access, user_type, permission_type, permission_behaviour where permission_type.permission = 'execute' AND node_access.node_id = $1 AND user_type.usertype = $2 AND node_access.user_type = user_type.user_type_pk AND node_access.permission_behaviour = permission_behaviour.permission_behaviour_pk  AND node_access.permission_type = permission_type.permission_type_pk)  WHEN 'enable' THEN 'x' WHEN 'disable' THEN '-' WHEN 'inherit' THEN 'i' END
||
CASE (  SELECT permission_behaviour.behaviour from node_access, user_type, permission_type, permission_behaviour where permission_type.permission = 'delete' AND node_access.node_id = $1 AND user_type.usertype = $2 AND node_access.user_type = user_type.user_type_pk AND node_access.permission_behaviour = permission_behaviour.permission_behaviour_pk AND node_access.permission_type = permission_type.permission_type_pk)  WHEN 'enable' THEN 'd' WHEN 'disable' THEN '-' WHEN 'inherit' THEN 'i' END
||
CASE WHEN $2 = 'author' OR $2 = 'defaultauthor' THEN '' ELSE ( CASE (  SELECT permission_behaviour.behaviour from node_access, user_type, permission_type, permission_behaviour where permission_type.permission = 'create' AND node_access.node_id = $1 AND user_type.usertype = $2 AND node_access.user_type = user_type.user_type_pk AND node_access.permission_behaviour = permission_behaviour.permission_behaviour_pk  AND node_access.permission_type = permission_type.permission_type_pk)  WHEN 'enable' THEN 'c' WHEN 'disable' THEN '-' WHEN 'inherit' THEN 'i' END)
END;

$$ LANGUAGE SQL;
},
q{
CREATE FUNCTION "related_node_id" ( bigint, varchar ) RETURNS bigint AS $$

SELECT node_relationship.hasa_node
       FROM node_relationship, node_relation_type
       WHERE node_relationship.node = $1
       AND node_relationship.relation_type = node_relation_type_pk
       AND node_relation_type.name = $2

$$ LANGUAGE SQL;
},
q{
CREATE TABLE "attribute_type" (
   name varchar(125) UNIQUE NOT NULL,
   description varchar(255),
   attribute_type_pk serial,
   PRIMARY KEY ("attribute_type_pk")
)
},
q{
CREATE TABLE "timestamp_attribute" (
    time timestamp NOT NULL,
    node bigint REFERENCES node_basic( node_id) ON DELETE CASCADE,
    PRIMARY KEY ("node")
)
},
q{
CREATE VIEW "node" AS
  SELECT node_basic.node_id AS node_id,
         node_basic.type_nodetype,
         node_title.title,
         related_node_id( node_basic.node_id, 'author_user') AS author_user,
         node_basic.createtime,
         node_modified.modified,
         node_statistics_hits.hits,
         related_node_id( node_basic.node_id, 'loc_location') AS loc_location,
         node_statistics_reputation.reputation,
         node_lock.lockedby_user,
         node_lock.locktime,
         nodepermissions( node_basic.node_id, 'author') AS authoraccess,
         nodepermissions( node_basic.node_id, 'group') AS groupaccess,
         nodepermissions( node_basic.node_id, 'other') AS otheraccess,
         nodepermissions( node_basic.node_id, 'guest') AS guestaccess,
         dynamicpermission( node_basic.node_id, 'author' ) as dynamicauthor_permission,
         dynamicpermission( node_basic.node_id, 'group' ) as dynamicgroup_permission,
         dynamicpermission( node_basic.node_id, 'other' ) as dynamicother_permission,
         dynamicpermission( node_basic.node_id, 'guest' ) as dynamicguest_permission,
         related_node_id( node_basic.node_id, 'group_usergroup') AS group_usergroup
  FROM
    node_basic
  LEFT JOIN
    node_modified ON node_modified.node_id = node_basic.node_id
  LEFT JOIN
    node_title ON node_basic.node_id = node_title.node_id
  LEFT JOIN
    node_statistics_hits ON node_basic.node_id = node_statistics_hits.node_id
  LEFT JOIN
    node_statistics_reputation ON node_basic.node_id = node_statistics_reputation.node_id
  LEFT JOIN
    node_lock ON node_basic.node_id = node_lock.node_id
;

},
q{
CREATE FUNCTION select_sqltables_nodetype( bigint, text ) RETURNS varchar AS $$
  DECLARE
   node_id ALIAS FOR $1;
   tabletype ALIAS FOR $2;
   tablename varchar;
   tablelist varchar := '';
  BEGIN
   FOR tablename IN  SELECT sqltable.sqltable_name FROM sqltable, sqltable_type, node_sqltable WHERE node_sqltable.nodetype_id = node_id AND node_sqltable.sqltable = sqltable.sqltable_pk AND sqltable.type = sqltable_type_pk AND sqltable_type.sqltable_type = tabletype  LOOP

    IF tablelist <> '' THEN
       tablelist := tablelist || ',' || tablename;
    ELSE
       tablelist := tablename;
    END IF;

   END LOOP;
  RETURN tablelist;
  END;
$$ LANGUAGE plpgsql


},
 q{
 CREATE VIEW "nodetype" AS
      SELECT node_basic.node_id AS nodetype_id,
             related_node_id( node_basic.node_id, 'restrict_nodetype' )  AS restrict_nodetype,
             related_node_id( node_basic.node_id, 'extends_nodetype' )  AS extends_nodetype,

             ( SELECT (CASE ( SELECT b.behaviour FROM node_authorisation a, permission_type t, permission_behaviour b WHERE a.node_id = node_basic.node_id AND a.permission_type = t.permission_type_pk AND t.permission = 'restrictdupes' AND a.permission_behaviour = b.permission_behaviour_pk ) WHEN 'enable' THEN 1 WHEN 'disable' THEN 0 WHEN 'inherit' THEN -1 END ) ) AS restrictdupes,

             ( SELECT  select_sqltables_nodetype( node_basic.node_id, 'attributetable' ) ) AS sqltable,

             (  SELECT  select_sqltables_nodetype( node_basic.node_id, 'grouptable' ) ) AS grouptable,

             nodepermissions( node_basic.node_id, 'defaultauthor' ) AS defaultauthoraccess,
             nodepermissions( node_basic.node_id, 'defaultgroup' ) AS defaultgroupaccess,
             nodepermissions( node_basic.node_id, 'defaultother' ) AS defaultotheraccess,
             nodepermissions( node_basic.node_id, 'defaultguest' ) AS defaultguestaccess,
             related_node_id( node_basic.node_id, 'defaultgroup_usergroup') AS defaultgroup_usergroup,

             dynamicpermission ( node_basic.node_id, 'defaultauthor') AS defaultauthor_permission,
             dynamicpermission ( node_basic.node_id, 'defaultgroup') AS defaultgroup_permission,
             dynamicpermission ( node_basic.node_id, 'defaultother') AS defaultother_permission,
             dynamicpermission ( node_basic.node_id, 'defaultguest') AS defaultguest_permission,
             ( SELECT maxrevisions FROM nodebase_node_revisions r WHERE r.node_id = node_basic.node_id ) AS maxrevisions,
             ( SELECT (CASE ( SELECT b.behaviour FROM node_authorisation a, permission_type t, permission_behaviour b WHERE a.node_id = node_basic.node_id AND a.permission_type = t.permission_type_pk AND t.permission = 'canworkspace' AND a.permission_behaviour = b.permission_behaviour_pk ) WHEN 'enable' THEN 1 WHEN 'disable' THEN 0 WHEN 'inherit' THEN -1 END ) ) AS canworkspace

      FROM node_basic
       LEFT JOIN nodegroup_restrict_type
       ON nodegroup_restrict_type.group_nodetype_id = node_basic.node_id
       LEFT JOIN nodebase_restrictdupes
       ON  nodebase_restrictdupes.nodetype_id = node_basic.node_id

     WHERE type_nodetype = 1;
},
        q{CREATE TABLE "node2" (
  "node_id" serial UNIQUE NOT NULL,
  "type_nodetype" bigint,
  "title" character(240),
  "author_user" bigint,
  "createtime" timestamp NOT NULL,
  "modified" timestamp,
  "hits" bigint,
  "loc_location" bigint,
  "reputation" bigint,
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

q{
CREATE OR REPLACE FUNCTION insert_permissions (bigint, text, text) RETURNS VOID AS $$
INSERT INTO node_access ( node_id, user_type, permission_type, permission_behaviour )
SELECT
$1,
user_type.user_type_pk,
permission_type.permission_type_pk,
permission_behaviour.permission_behaviour_pk
FROM user_type, permission_type, permission_behaviour
WHERE permission_type.permission = 'read'
AND   user_type.usertype = $2
AND   permission_behaviour.behaviour = CASE substring( $3 from 1 for 1 ) WHEN 'r' THEN 'enable' WHEN '-' THEN 'disable' WHEN 'i' THEN 'inherit' ELSE NULL END;


INSERT INTO node_access ( node_id, user_type, permission_type, permission_behaviour )
SELECT
$1,
user_type.user_type_pk,
permission_type.permission_type_pk,
permission_behaviour.permission_behaviour_pk
FROM user_type, permission_type, permission_behaviour
WHERE permission_type.permission = 'write'
AND   user_type.usertype = $2
AND   permission_behaviour.behaviour = CASE substring( $3 from 2 for 1 ) WHEN 'w' THEN 'enable' WHEN '-' THEN 'disable' WHEN 'i' THEN 'inherit' ELSE NULL END;

INSERT INTO node_access ( node_id, user_type, permission_type, permission_behaviour )
SELECT
$1,
user_type.user_type_pk,
permission_type.permission_type_pk,
permission_behaviour.permission_behaviour_pk
FROM user_type, permission_type, permission_behaviour
WHERE permission_type.permission = 'execute'
AND   user_type.usertype = $2
AND   permission_behaviour.behaviour = CASE substring( $3 from 3 for 1 ) WHEN 'x' THEN 'enable' WHEN '-' THEN 'disable' WHEN 'i' THEN 'inherit' ELSE NULL END;


INSERT INTO node_access ( node_id, user_type, permission_type, permission_behaviour )
SELECT
$1,
user_type.user_type_pk,
permission_type.permission_type_pk,
permission_behaviour.permission_behaviour_pk
FROM user_type, permission_type, permission_behaviour
WHERE permission_type.permission = 'delete'
AND   user_type.usertype = $2
AND   permission_behaviour.behaviour = CASE substring( $3 from 4 for 1 ) WHEN 'd' THEN 'enable' WHEN '-' THEN 'disable' WHEN 'i' THEN 'inherit' ELSE NULL END;


INSERT INTO node_access ( node_id, user_type, permission_type, permission_behaviour )
SELECT
$1,
user_type.user_type_pk,
permission_type.permission_type_pk,
permission_behaviour.permission_behaviour_pk
FROM user_type, permission_type, permission_behaviour
WHERE permission_type.permission = 'create'
AND   user_type.usertype = $2
AND   substring( $3 from 5 for 1 ) <> ''
AND   permission_behaviour.behaviour = CASE substring( $3 from 5 for 1 ) WHEN 'c' THEN 'enable' WHEN '-' THEN 'disable' WHEN 'i' THEN 'inherit' ELSE NULL END;



$$ LANGUAGE SQL;

}
,
q{
CREATE OR REPLACE FUNCTION update_permissions (bigint, text, text) RETURNS VOID AS $$

DELETE FROM node_access WHERE node_access.node_id = $1 AND user_type = ( SELECT user_type.user_type_pk FROM user_type where user_type.usertype = $2 );

SELECT insert_permissions( $1, $2, $3 );

$$ LANGUAGE SQL;
},
q{
CREATE FUNCTION insert_node_relation (bigint, bigint, varchar) RETURNS VOID AS $$
-- node_id, hasa node_id, relation type
INSERT INTO node_relationship (hasa_node, node, relation_type )
  SELECT $2, $1, node_relation_type.node_relation_type_pk
  FROM node_relation_type WHERE node_relation_type.name = $3 AND $2 IS NOT NULL;

$$ LANGUAGE SQL;
},
q{
CREATE FUNCTION insert_dynamic_permission ( bigint, bigint, varchar ) RETURNS VOID AS $$
--node_id, permission_id, user_type

INSERT INTO node_relationship_usertype (node, with_node, relation_type, user_type ) SELECT  $1, $2, ( SELECT node_relation_type_pk FROM node_relation_type WHERE name = 'dynamic permission' ), ( SELECT user_type_pk FROM user_type WHERE user_type.usertype = $3) WHERE $2 IS NOT NULL;


$$ LANGUAGE SQL;
},
q{
CREATE RULE _insert_node AS ON INSERT TO node
DO INSTEAD (
INSERT INTO node_basic ( type_nodetype, createtime ) VALUES ( NEW.type_nodetype, now() );

SELECT insert_node_relation( currval('node_basic_node_id_seq'), NEW.author_user, 'author_user' );

INSERT INTO node_title (title, node_id ) SELECT NEW.title, currval('node_basic_node_id_seq') WHERE NEW.title IS NOT NULL;

INSERT INTO node_statistics_hits (hits, node_id )  SELECT NEW.hits, currval('node_basic_node_id_seq') WHERE NEW.hits IS NOT NULL;

SELECT insert_node_relation ( currval('node_basic_node_id_seq'), NEW.loc_location, 'loc_location' );

INSERT INTO node_statistics_reputation (reputation, node_id ) SELECT NEW.reputation, currval('node_basic_node_id_seq') WHERE NEW.reputation IS NOT NULL;

INSERT INTO node_lock (locktime, lockedby_user, node_id ) SELECT NEW.locktime, NEW.lockedby_user, currval('node_basic_node_id_seq') WHERE NEW.locktime IS NOT NULL;

SELECT insert_node_relation( currval('node_basic_node_id_seq'), NEW.group_usergroup, 'group_usergroup' );

SELECT insert_permissions(  currval('node_basic_node_id_seq'), 'author', NEW.authoraccess );

SELECT insert_permissions(  currval('node_basic_node_id_seq'), 'group', NEW.groupaccess );

SELECT insert_permissions(  currval('node_basic_node_id_seq'), 'other', NEW.otheraccess );

SELECT insert_permissions(  currval('node_basic_node_id_seq'), 'guest', NEW.guestaccess );

SELECT insert_dynamic_permission( NEW.node_id, NEW.dynamicauthor_permission, 'author' );
SELECT insert_dynamic_permission( NEW.node_id, NEW.dynamicauthor_permission, 'group' );
SELECT insert_dynamic_permission( NEW.node_id, NEW.dynamicauthor_permission, 'other' );
SELECT insert_dynamic_permission( NEW.node_id, NEW.dynamicauthor_permission, 'guest' );

)
},
q{
CREATE FUNCTION update_dynamicpermission (bigint, text, bigint ) RETURNS VOID AS $$
-- node_id, author type, permission_id
DELETE FROM node_relationship_usertype WHERE node = $1 AND relation_type = (SELECT node_relation_type_pk FROM node_relation_type WHERE node_relation_type.name = 'dynamic permission' ) AND user_type = ( SELECT user_type_pk FROM user_type WHERE usertype = $2 ) AND $3 IS NULL;
UPDATE node_relationship_usertype SET with_node = $3 WHERE node = $1 AND user_type = ( SELECT user_type_pk FROM user_type WHERE user_type.usertype = $2 ) AND relation_type =  ( SELECT node_relation_type_pk FROM node_relation_type WHERE node_relation_type.name = 'dynamic permission' ) AND $3 IS NOT NULL AND $3 <> 0;
INSERT INTO node_relationship_usertype (with_node, user_type, node, relation_type) SELECT $3, ( SELECT user_type_pk FROM user_type WHERE usertype = $2 ), $1, ( SELECT node_relation_type_pk FROM node_relation_type where name = 'dynamic permission') WHERE $3 IS NOT NULL AND $3 <> 0 AND NOT EXISTS ( SELECT * FROM node_relationship_usertype, user_type, node_relation_type WHERE node_relationship_usertype.node = $1 AND node_relationship_usertype.user_type = ( SELECT user_type.user_type_pk FROM user_type WHERE usertype = $2 ) AND node_relationship_usertype.relation_type = ( SELECT node_relation_type_pk from node_relation_type where name = 'dynamic permission'));


$$ LANGUAGE SQL;

},
q{
-- First arg is the node_id from.  The second is the 'has-a' node.  The third is the relationship type.

CREATE FUNCTION update_node_relation (bigint, bigint, varchar ) RETURNS VOID AS $$

DELETE FROM node_relationship WHERE $1 = node_relationship.node AND node_relationship.relation_type = ( SELECT node_relation_type.node_relation_type_pk FROM node_relation_type WHERE node_relation_type.name = $3 ) AND $2 IS NULL;

 UPDATE node_relationship SET hasa_node = $2
  WHERE
       node_relationship.node =  $1
    AND $2 IS NOT NULL
    AND node_relationship.relation_type = ( SELECT node_relation_type_pk
           FROM node_relation_type
           WHERE node_relation_type.name = $3);


INSERT INTO node_relationship (hasa_node, node, relation_type )
  SELECT $2, $1, node_relation_type.node_relation_type_pk
    FROM node_relation_type
    WHERE node_relation_type.name = $3
     AND $2 IS NOT NULL
     AND
      NOT EXISTS (
       SELECT *
         FROM node_relationship, node_relation_type
         WHERE node_relationship.node = $1
          AND node_relationship.relation_type = node_relation_type.node_relation_type_pk
          AND node_relation_type.name = $3
       );


$$ LANGUAGE SQL;
},
q{
CREATE RULE _update_node AS ON UPDATE TO node
DO INSTEAD (
UPDATE node_basic SET  type_nodetype =  NEW.type_nodetype WHERE NEW.type_nodetype <> OLD.type_nodetype AND NEW.node_id = node_basic.node_id;

SELECT update_node_relation( NEW.node_id, NEW.author_user, 'author_user' );

DELETE FROM node_title WHERE NEW.node_id = node_title.node_id AND NEW.title IS NULL;
UPDATE node_title SET title = NEW.title WHERE NEW.node_id = node_title.node_id AND NEW.title IS NOT NULL;
INSERT INTO node_title (title, node_id) SELECT NEW.title, NEW.node_id WHERE NEW.title IS NOT NULL AND NOT EXISTS ( SELECT * FROM node_title WHERE node_title.node_id = NEW.node_id );

DELETE FROM node_statistics_hits WHERE NEW.node_id = node_statistics_hits.node_id AND NEW.hits IS NULL;
UPDATE node_statistics_hits  SET hits =  NEW.hits  WHERE NEW.node_id = node_statistics_hits.node_id;
INSERT INTO node_statistics_hits (hits, node_id) SELECT NEW.hits, NEW.node_id WHERE NEW.hits IS NOT NULL AND NOT EXISTS ( SELECT * FROM node_statistics_hits WHERE node_statistics_hits.node_id = NEW.node_id );

SELECT update_node_relation( NEW.node_id, NEW.loc_location, 'loc_location' );

DELETE FROM node_statistics_reputation WHERE NEW.node_id = node_statistics_reputation.node_id AND NEW.reputation IS NULL;
UPDATE node_statistics_reputation SET reputation =  NEW.reputation WHERE NEW.node_id = node_statistics_reputation.node_id AND NEW.reputation IS NOT NULL;
INSERT INTO node_statistics_reputation (reputation, node_id) SELECT NEW.reputation, NEW.node_id WHERE NEW.reputation IS NOT NULL AND NOT EXISTS ( SELECT * FROM node_statistics_reputation WHERE node_statistics_reputation.node_id = NEW.node_id );

DELETE FROM node_lock WHERE NEW.node_id = node_lock.node_id AND ( NEW.locktime IS NULL OR NEW.lockedby_user IS NULL );
UPDATE node_lock SET locktime = NEW.locktime, lockedby_user = NEW.lockedby_user WHERE NEW.node_id = node_lock.node_id AND NEW.locktime IS NOT NULL AND NEW.lockedby_user IS NOT NULL;
INSERT INTO node_lock (locktime, lockedby_user, node_id) SELECT NEW.locktime, NEW.lockedby_user, NEW.node_id WHERE NEW.locktime IS NOT NULL AND NEW.lockedby_user IS NOT NULL AND NOT EXISTS ( SELECT * FROM node_lock WHERE node_lock.node_id = NEW.node_id );


SELECT update_node_relation( NEW.node_id, NEW.group_usergroup, 'group_usergroup');

SELECT update_dynamicpermission( NEW.node_id, 'author', NEW.dynamicauthor_permission );
SELECT update_dynamicpermission( NEW.node_id, 'group', NEW.dynamicgroup_permission );
SELECT update_dynamicpermission( NEW.node_id, 'other', NEW.dynamicother_permission );
SELECT update_dynamicpermission( NEW.node_id, 'author', NEW.dynamicguest_permission );

SELECT update_permissions( NEW.node_id, 'author', NEW.authoraccess );
SELECT update_permissions( NEW.node_id, 'group', NEW.groupaccess );
SELECT update_permissions( NEW.node_id, 'other', NEW.otheraccess );
SELECT update_permissions( NEW.node_id, 'guest', NEW.guestaccess );

)
},

q{
CREATE RULE _delete_node AS ON DELETE TO node
DO INSTEAD (

DELETE FROM node_basic where node_basic.node_id = OLD.node_id;

)
},
q{
CREATE OR REPLACE FUNCTION split_on_comma(text) RETURNS SETOF varchar AS $$
DECLARE
 index INTEGER := 1;
 tablename varchar;
BEGIN

  IF $1 IS NULL THEN
    RETURN;
  END IF;

  LOOP
    tablename := split_part( $1, ',',index );
    IF tablename = '' THEN
       EXIT;
    END IF;
    index := index + 1;

    RETURN NEXT tablename;
  END LOOP;

RETURN;

END;
$$ LANGUAGE plpgsql

},

q{
CREATE FUNCTION insert_sqltable_data( text, text, bigint ) RETURNS VOID AS $$
  DECLARE
   tablelist ALIAS FOR $1;
   tabletype ALIAS FOR $2;
   node_id ALIAS FOR $3;
   tablename varchar;
  BEGIN
   FOR tablename IN SELECT * FROM split_on_comma( tablelist ) LOOP
    INSERT INTO sqltable (sqltable_name, type ) SELECT tablename, sqltable_type_pk FROM sqltable_type WHERE sqltable_type.sqltable_type = tabletype AND NOT EXISTS ( SELECT * FROM sqltable WHERE sqltable.sqltable_name = tablename );

    INSERT INTO node_sqltable (nodetype_id, sqltable) SELECT node_id, sqltable_pk FROM sqltable WHERE sqltable_name = tablename AND NOT EXISTS ( SELECT * FROM node_sqltable, sqltable_type, sqltable WHERE node_sqltable.nodetype_id = node_id AND node_sqltable.sqltable = sqltable.sqltable_pk and sqltable.type = sqltable_type.sqltable_type_pk and sqltable_type.sqltable_type = tabletype AND sqltable.sqltable_name = tablename);

   END LOOP;
  RETURN;
  END;
$$ LANGUAGE plpgsql
},
q{
CREATE RULE _insert_nodetype AS ON INSERT TO nodetype DO INSTEAD (

  SELECT insert_node_relation( NEW.nodetype_id, NEW.restrict_nodetype, 'restrict_nodetype');

  SELECT insert_node_relation( NEW.nodetype_id, NEW.extends_nodetype, 'extends_nodetype') WHERE NEW.extends_nodetype <> 0;


  INSERT INTO node_authorisation ( node_id, permission_type, permission_behaviour )
   SELECT
    NEW.nodetype_id,
    permission_type.permission_type_pk,
    permission_behaviour.permission_behaviour_pk
    FROM permission_type, permission_behaviour
    WHERE permission_type.permission = 'restrictdupes'
    AND   permission_behaviour.behaviour = CASE NEW.restrictdupes WHEN '1' THEN 'enable' WHEN '0' THEN 'disable' WHEN '-1' THEN 'inherit' ELSE NULL END;

  SELECT insert_sqltable_data( NEW.sqltable, 'attributetable', NEW.nodetype_id );
  SELECT insert_sqltable_data( NEW.grouptable, 'grouptable', NEW.nodetype_id );

  SELECT insert_permissions( NEW.nodetype_id, 'defaultauthor', NEW.defaultauthoraccess );
  SELECT insert_permissions( NEW.nodetype_id, 'defaultgroup', NEW.defaultgroupaccess );
  SELECT insert_permissions( NEW.nodetype_id, 'defaultother', NEW.defaultotheraccess );
  SELECT insert_permissions( NEW.nodetype_id, 'defaultguest', NEW.defaultguestaccess );

SELECT insert_node_relation( NEW.nodetype_id, NEW.defaultgroup_usergroup, 'defaultgroup_usergroup' );

  SELECT insert_dynamic_permission ( NEW.nodetype_id, NEW.defaultauthor_permission, 'defaultauthor' );
  SELECT insert_dynamic_permission ( NEW.nodetype_id, NEW.defaultgroup_permission, 'defaultgroup' );
  SELECT insert_dynamic_permission ( NEW.nodetype_id, NEW.defaultother_permission, 'defaultother' );
  SELECT insert_dynamic_permission ( NEW.nodetype_id, NEW.defaultguest_permission, 'defaultguest' );

  INSERT INTO nodebase_node_revisions (node_id, maxrevisions) SELECT  NEW.nodetype_id, NEW.maxrevisions WHERE NEW.maxrevisions IS NOT NULL;

  INSERT INTO node_authorisation ( node_id, permission_type, permission_behaviour )
   SELECT
    NEW.nodetype_id,
    permission_type.permission_type_pk,
    permission_behaviour.permission_behaviour_pk
    FROM permission_type, permission_behaviour
    WHERE permission_type.permission = 'canworkspace'
    AND   permission_behaviour.behaviour = CASE NEW.canworkspace WHEN '1' THEN 'enable' WHEN '0' THEN 'disable' WHEN '-1' THEN 'inherit' ELSE NULL END;

)
},
q{
CREATE FUNCTION update_sqltable_data( text, text, bigint ) RETURNS VOID AS $$
  DECLARE
   tablelist ALIAS FOR $1;
   tabletype ALIAS FOR $2;
   node_id ALIAS FOR $3;
   tablename varchar;
  BEGIN

   DELETE FROM node_sqltable WHERE nodetype_id = node_id AND sqltable in ( SELECT sqltable_pk FROM sqltable, sqltable_type WHERE  sqltable.type = sqltable_type_pk AND sqltable_type.sqltable_type = tabletype);
   PERFORM insert_sqltable_data( tablelist, tabletype, node_id );

  RETURN;

  END;
$$ LANGUAGE plpgsql
},
q{
CREATE FUNCTION update_node_authorisation (bigint, integer, varchar ) RETURNS VOID AS $$

-- nodetype_id, authorisation, authorisation_type

DELETE FROM node_authorisation WHERE node_authorisation.node_id = $1 AND  node_authorisation.permission_type = ( SELECT permission_type.permission_type_pk FROM permission_type WHERE permission_type.permission = $3) AND $2 IS NULL;

UPDATE node_authorisation SET permission_behaviour = ( SELECT permission_behaviour_pk FROM permission_behaviour WHERE permission_behaviour.behaviour = CASE $2 WHEN '1' THEN 'enable' WHEN '0' THEN 'disable' WHEN '-1' THEN 'inherit' ELSE NULL END ) WHERE node_authorisation.node_id = $1  AND node_authorisation.permission_type = ( SELECT permission_type_pk FROM permission_type where permission_type.permission = $3 );

  INSERT INTO node_authorisation ( node_id, permission_type, permission_behaviour )
   SELECT
    $1,
    permission_type.permission_type_pk,
    permission_behaviour.permission_behaviour_pk
    FROM permission_type, permission_behaviour
    WHERE permission_type.permission = $3
    AND NOT EXISTS ( SELECT * FROM node_authorisation, permission_type WHERE node_authorisation.node_id = $1 AND node_authorisation.permission_type = permission_type.permission_type_pk AND permission_type.permission = $3)
    AND   permission_behaviour.behaviour = ( SELECT CASE $2 WHEN '1' THEN 'enable' WHEN '0' THEN 'disable' WHEN '-1' THEN 'inherit' ELSE NULL END );

$$ LANGUAGE SQL;
},
q{
CREATE RULE _update_nodetype AS ON UPDATE to nodetype DO INSTEAD (

  SELECT update_node_relation( NEW.nodetype_id, NEW.restrict_nodetype, 'restrict_nodetype') WHERE NEW.restrict_nodetype <> 0;

  SELECT update_node_relation( NEW.nodetype_id, NEW.extends_nodetype, 'extends_nodetype') WHERE NEW.extends_nodetype <> 0;


  SELECT update_node_authorisation( NEW.nodetype_id, NEW.restrictdupes, 'restrictdupes');

  SELECT update_sqltable_data( NEW.sqltable, 'attributetable', NEW.nodetype_id );
  SELECT update_sqltable_data( NEW.grouptable, 'grouptable', NEW.nodetype_id );


  SELECT update_permissions( NEW.nodetype_id, 'defaultauthor', NEW.defaultauthoraccess );
  SELECT update_permissions( NEW.nodetype_id, 'defaultgroup', NEW.defaultgroupaccess );
  SELECT update_permissions( NEW.nodetype_id, 'defaultother', NEW.defaultotheraccess );
  SELECT update_permissions( NEW.nodetype_id, 'defaultguest', NEW.defaultguestaccess );

SELECT update_node_relation( NEW.nodetype_id, NEW.defaultgroup_usergroup, 'defaultgroup_usergroup' ) WHERE NEW.defaultgroup_usergroup <> 0;

  SELECT update_dynamicpermission ( NEW.nodetype_id,  'defaultauthor', NEW.defaultauthor_permission );
  SELECT update_dynamicpermission ( NEW.nodetype_id, 'defaultgroup', NEW.defaultgroup_permission );
  SELECT update_dynamicpermission ( NEW.nodetype_id, 'defaultother', NEW.defaultother_permission );
  SELECT update_dynamicpermission ( NEW.nodetype_id, 'defaultguest', NEW.defaultguest_permission );

  DELETE FROM nodebase_node_revisions WHERE nodebase_node_revisions.node_id = NEW.nodetype_id AND NEW.maxrevisions IS NULL;
  UPDATE nodebase_node_revisions SET maxrevisions=NEW.maxrevisions WHERE NEW.maxrevisions IS NOT NULL AND nodebase_node_revisions.node_id = NEW.nodetype_id AND EXISTS (SELECT * FROM nodebase_node_revisions where nodebase_node_revisions.node_id = NEW.nodetype_id );
  INSERT INTO nodebase_node_revisions (node_id, maxrevisions ) SELECT NEW.nodetype_id, NEW.maxrevisions WHERE NEW.maxrevisions IS NOT NULL AND NOT EXISTS (SELECT * FROM nodebase_node_revisions WHERE nodebase_node_revisions.node_id = NEW.nodetype_id);

   SELECT update_node_authorisation ( NEW.nodetype_id, NEW.canworkspace, 'canworkspace' );

)
},
        q{CREATE TABLE version (
  version_id INTEGER  PRIMARY KEY DEFAULT '0' NOT NULL,
  version INTEGER DEFAULT '1' NOT NULL
)}
    );
}

sub base_nodes {

    return (
q{INSERT INTO sqltable_type ( sqltable_type, description) VALUES ('attributetable', 'A table of this type contains node attribute data.') },
q{INSERT INTO sqltable_type ( sqltable_type, description) VALUES ('grouptable', 'A table of this type contains a list of nodes contained in a type.') },
q{INSERT INTO node_relation_type ( name, description ) VALUES ('author_user', 'the user node identified as author of a node') },
q{INSERT INTO node_relation_type ( name, description ) VALUES ('group_usergroup', 'the usergroup node associated with a node') },
q{INSERT INTO node_relation_type ( name, description ) VALUES ('defaultgroup_usergroup', 'the default usergroup node associated with a node') },
q{INSERT INTO node_relation_type ( name, description ) VALUES ('extends_nodetype', 'the nodetype that this node extends') },
q{INSERT INTO node_relation_type ( name, description ) VALUES ('type_nodetype', 'the nodetype node of a node') },
q{INSERT INTO node_relation_type ( name, description ) VALUES ('loc_location', 'the location node of a node') },
q{INSERT INTO node_relation_type ( name, description ) VALUES ('restrict_nodetype', 'for group nodes: restrict the nodes contained in this group to this type.') },
q{INSERT INTO node_relation_type ( name, description ) VALUES ('dynamic permission', 'where access to a node is determined by a perimssion node.') },
q{INSERT INTO node_relation_type ( name, description ) VALUES ('permission', 'a dynamic permission node for the node') },
q{INSERT INTO user_type (usertype, description) VALUES ('author', 'an author of a node')},
q{INSERT INTO user_type (usertype, description) VALUES ('group', 'whether an author is a member of a group')},
q{INSERT INTO user_type (usertype, description) VALUES ('other', 'a user is logged in but is neither in the relevant group not an author')},
q{INSERT INTO user_type (usertype, description) VALUES ('guest', 'usually used to refer to an anonymous user or one that is not in any other category')},
q{INSERT INTO user_type (usertype, description) VALUES ('defaultauthor', 'what an author type defaults to.')},
q{INSERT INTO user_type (usertype, description) VALUES ('defaultgroup', 'what members of a group default to.')},
q{INSERT INTO user_type (usertype, description) VALUES ('defaultother', 'what other users default to.')},
q{INSERT INTO user_type (usertype, description) VALUES ('defaultguest', 'what guests default to.')},
q{INSERT INTO permission_type (permission, description) VALUES ('read', 'the permission to read an object')},
q{INSERT INTO permission_type (permission, description) VALUES ('write', 'the permission to write to an object')},
q{INSERT INTO permission_type (permission, description) VALUES ('execute', 'the permission to "execute" an object, that is, run any code in it')},
q{INSERT INTO permission_type (permission, description) VALUES ('delete', 'the permission to delete an object')},
q{INSERT INTO permission_type (permission, description) VALUES ('create', 'the permission to create an object')},
q{INSERT INTO permission_type (permission, description) VALUES ('canworkspace', 'whether the node can be workspaced')},
q{INSERT INTO permission_type (permission, description) VALUES ('restrictdupes', 'whether the nodebase allows creation of nodes with a similar name')},
q{INSERT INTO permission_behaviour (behaviour, description) VALUES ('enable', 'the permission for this object is enabled')},
q{INSERT INTO permission_behaviour (behaviour, description) VALUES ('disable', 'the permission for this object is disabled')},
q{INSERT INTO permission_behaviour (behaviour, description) VALUES ('inherit', 'the permission for this object is inherited according to some algorithm')},
q{INSERT INTO node (node_id, type_nodetype, title, createtime, authoraccess, groupaccess, otheraccess, guestaccess ) VALUES (1,1,'nodetype',now(), 'iiii','rwxdc','-----','-----' )},
q{INSERT INTO node (node_id, type_nodetype, title, createtime, authoraccess, groupaccess, otheraccess, guestaccess ) VALUES (2,1,'node',now(),'rwxd','-----','-----','-----')},
q{INSERT INTO node (node_id, type_nodetype, title, createtime, authoraccess, groupaccess, otheraccess, guestaccess ) VALUES (3,1,'setting', now(),'rwxd','-----','-----','-----')},
q{INSERT INTO nodetype (nodetype_id, restrict_nodetype, extends_nodetype, restrictdupes, sqltable, grouptable, defaultauthoraccess, defaultgroupaccess, defaultotheraccess, defaultguestaccess, defaultgroup_usergroup, defaultauthor_permission, defaultgroup_permission, defaultother_permission, defaultguest_permission, maxrevisions, canworkspace ) VALUES (1,NULL,2,1,'nodetype','','rwxd','rwxdc','-----','-----',NULL,NULL,NULL,NULL,NULL,-1,0)},
q{INSERT INTO nodetype (nodetype_id, restrict_nodetype, extends_nodetype, restrictdupes, sqltable, grouptable, defaultauthoraccess, defaultgroupaccess, defaultotheraccess, defaultguestaccess, defaultgroup_usergroup, defaultauthor_permission, defaultgroup_permission, defaultother_permission, defaultguest_permission, maxrevisions, canworkspace ) VALUES (2,NULL,NULL,1,'','','rwxd','r----','-----','-----',NULL,NULL,NULL,NULL,NULL,1000,1)},
q{INSERT INTO nodetype (nodetype_id, restrict_nodetype, extends_nodetype, restrictdupes, sqltable, grouptable, defaultauthoraccess, defaultgroupaccess, defaultotheraccess, defaultguestaccess, defaultgroup_usergroup, defaultauthor_permission, defaultgroup_permission, defaultother_permission, defaultguest_permission, maxrevisions, canworkspace ) VALUES (3,NULL,2,1,'setting','','rwxd','-----','-----','-----',NULL,NULL,NULL,NULL,NULL,-1,-1)},

      )

}

1;
