
=head1 Everything::DB

Wrapper for the Everything database.

Copyright 2006 Everything Development Inc.

=cut

package Everything::DB;

use strict;
use warnings;

use Everything::Node;
use DBI;
use Scalar::Util 'weaken';

sub new
{
	my ($class, %args) = @_;
	weaken( $args{nb} );
	bless \%args, $class;
}

=head2 C<fetch_all_nodetype_names()>

This method returns a list of the names of all nodetypes in the system. Takes an optional argument, which is text passed to sqlSelectMany.

=cut

sub fetch_all_nodetype_names
{
	my ( $self, $order_by )  = @_;

	$order_by ||= 'ORDER BY node_id';
	my $csr  = $self->sqlSelectMany( 'title', 'node', 'type_nodetype=1', $order_by );

	return unless $csr;

	my @modules;

	while ( my ($title) = $csr->fetchrow_array() )
	{
		$title =~ s/\W//g;
		push @modules, $title;
	}

	return @modules;
}

=head2 C<getDatabaseHandle>

This returns the DBI connection to the database.  This can be used to do raw
database queries.  Unless you are doing something very specific, you shouldn't
need to access this.

Returns the DBI database connection for this NodeBase.

=cut

sub getDatabaseHandle
{
	my ($this) = @_;

	return $this->{dbh};
}

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

	return $this->getDatabaseHandle()->last_insert_id();
}

=head2 C<sqlDelete>

Quickie wrapper for deleting a row or rows from a specified table.

=over 4

=item * table

the sql table to delete the row from

=item * where

what the sql query should match when deleting.

=item * bound

an array reference of bound variables

=back

Returns 0 (false) if the sql command fails, 1 (true) if successful.

=cut

sub sqlDelete
{
	my ( $this, $table, $where, $bound ) = @_;
	$bound ||= [];

	return unless $where;

	my $sql = "DELETE FROM " . $this->genTableName($table) . " WHERE $where";
	my $sth = $this->{dbh}->prepare($sql);
	return $sth->execute(@$bound)
		or Everything::logErrors( '', "Delete failed: '$sql' [@$bound]" );
}

=head2 C<sqlSelect>

Select specific fields from a single record.  If you need multiple records, use
sqlSelectMany.

=over 4

=item * select

what columns to return from the select (ie "*")

=item * table

the table to do the select on

=item * where

string containing the search criteria

=item * other

any other sql options thay you may want to pass

=back

Returns an arrayref of values from the specified fields in $select.  If there
is only one field, the return will be that value, not an array.  Undef if no
matches in the sql select.

=cut

sub sqlSelect
{
	my $this = shift;
	return unless my $cursor = $this->sqlSelectMany(@_);

	my @result = $cursor->fetchrow();
	$cursor->finish();

	return unless @result;
	return $result[0] if @result == 1;
	return \@result;
}

=head2 C<sqlSelectJoined>

A general wrapper function for a standard SQL select command involving left
joins.  This returns the DBI cursor.

=over 4

=item * select

what columns to return from the select (ie "*")

=item * table

the table to do the select on

=item * joins

a hash consisting of the table name and the join criteria

=item * where

the search criteria

=item * other

any other sql options that you may want to pass

=back

Returns the sql cursor of the select.  Call fetchrow() on it to get the
selected rows.  undef if error.

=cut

sub sqlSelectJoined
{
	my ( $this, $select, $table, $joins, $where, $other, $bound ) = @_;

	my $sql = "SELECT $select ";
	$sql .= "FROM " . $this->genTableName($table) . " " if $table;

	while ( my ( $join, $column ) = each %$joins )
	{
		$sql .= "LEFT JOIN " . $this->genTableName($join) . " ON $column ";
	}

	$sql .= "WHERE $where " if $where;
	$sql .= $other          if $other;

	my $cursor = $this->{dbh}->prepare($sql);
	die "$DBI::errstr, $sql" if $DBI::errstr;

	$cursor->execute(@$bound);
	die "$DBI::errstr, $sql, @$bound" if $DBI::errstr;

	return $cursor;
}

=head2 C<sqlSelectMany>

A general wrapper function for a standard SQL select command.  This returns the
DBI cursor.

=over 4

=item * select

what columns to return from the select (ie "*")

=item * table

the table to do the select on

=item * where

the search criteria

=item * other

any other sql options that you may want to pass

=item * bound

any bound values for placeholders 

=back

Returns the sql cursor of the select.  Call fetchrow() on it to get the
selected rows.  undef if error.

=cut

sub sqlSelectMany
{
	my ( $this, $select, $table, $where, $other, $bound ) = @_;

	$bound ||= [];

	my $sql = "SELECT $select ";
	$sql .= "FROM " . $this->genTableName($table) . " " if $table;
	$sql .= "WHERE $where "                             if $where;
	$sql .= $other                                      if $other;

	my $cursor = $this->{dbh}->prepare($sql) or return;

	return $cursor if $cursor->execute(@$bound);
	return;
}

=head2 C<sqlSelectHashref>

Grab one row from a table and return it as a hash.  This just grabs the first
row from the select and returns it as a hash.  If you want more than the first
row, call sqlSelectMany and retrieve them yourself.  This is basically a
quickie for getting a single row.

=over 4

=item * select

what colums to return from the select (ie "*")

=item * table

the table to do the select on

=item * where

the search criteria

=item * other

any other sql options thay you may wan to pass

=back

Returns a hashref to the row that matches the query.  undef if no match.

=cut

sub sqlSelectHashref
{
	my $this   = shift;
	my $cursor = $this->sqlSelectMany(@_) or return;
	my $hash   = $cursor->fetchrow_hashref();

	$cursor->finish();
	return $hash;
}

=head2 C<sqlUpdate>

Wrapper for sql update command.

=over 4

=item * table

the sql table to udpate

=item * data

a hash reference that contains the fields and their values that will be
changed.

=item * where

the string that contains the constraints as to which rows will be updated.

=back

Returns number of rows affected (true if something happened, false if nothing
was changed).

=cut

sub sqlUpdate
{
	my ( $this, $table, $data, $where, $prebound ) = @_;

	return unless keys %$data;
	my ( $names, $values, $bound ) = $this->_quoteData($data);

	my $sql = "UPDATE "
		. $this->genTableName($table) . " SET "
		. join( ",\n", map { "$_ = " . shift @$values } @$names );

	$sql .= "\nWHERE $where\n" if $where;
	push @$bound, @$prebound if $prebound and @$prebound;

	return $this->sqlExecute( $sql, $bound );
}

=head2 C<sqlInsert>

Wrapper for the sql insert command.

=over 4

=item * table

string name of the sql table to add the new row

=item * data

a hash reference that contains the fieldname =E<gt> value pairs.  If the
fieldname starts with a '-', the value is treated as a literal value and thus
not quoted/escaped.

=back

Returns true if successful, false otherwise.

=cut

sub sqlInsert
{
	my ( $this, $table, $data ) = @_;

	my ( $names, $values, $bound ) = $this->_quoteData($data);
	my $sql =
		  "INSERT INTO "
		. $this->genTableName($table) . " ("
		. join( ', ', @$names )
		. ") VALUES("
		. join( ', ', @$values ) . ")";

        my $rv = $this->sqlExecute( $sql, $bound );
	Everything::logErrors( "$sql $DBI::errstr @$bound" )if $DBI::errstr;
	return $rv;
}


=head2 C<update_or_insert>

This updates a row in a table if it doesn't exist, else inserts it.

It takes one argument a hash ref, that may have the following key/value pairs:

=over 4

=item * table

the sql table to udpate

=item * data

a hash reference that contains the fields and their values that will be
changed.

=item * where

the string that contains the constraints as to which rows will be updated.

=item * bound

an array reference of the values to be bound to what's in the where clause

=item * node_id

the unique identifier of the node object to which this query relates

=back

Returns number of rows affected (true if something happened, false if nothing
was changed).

=cut

sub update_or_insert {

        my ( $this, $args ) = @_;
	my ( $table, $data, $where, $prebound, $node_id ) = ( $$args{table}, $$args{data}, $$args{ where }, $$args{ bound }, $$args{ node_id} );

	my $exists = $this->sqlSelect( 'count(1)', $table, $where, undef, $prebound );

	if ( $exists ) {
	    $this->sqlUpdate( $table, $data, $where, $prebound );
	} else {

	    $data->{$table . '_id'} = $node_id;
	    $this->sqlInsert( $table, $data );
	}

}



=head2 C<_quoteData>

Private method

Quote database per existing convention:

=over 4

=item * column name =E<gt> value

=item * leading '-' means use placeholder (quote) value

=back

=cut

sub _quoteData
{
	my ( $this, $data ) = @_;

	my ( @names, @values, @bound );

	while ( my ( $name, $value ) = each %$data )
	{
		if ( $name =~ s/^-// )
		{
			push @values, $value;
		}
		else
		{
			push @values, '?';
			push @bound,  $value;
		}
		push @names, $name;
	}

	return \@names, \@values, \@bound;
}

=head2 C<sqlExecute>

Wrapper for the SQL execute command.

=over 4

=item * sql  

the SQL to execute

=item * bound

a reference to an array of bound variables to be used with placeholders

=back

Returns true (number of rows affected) if successful, false otherwise.
Failures are logged.

=cut

sub sqlExecute
{
	my ( $this, $sql, $bound ) = @_;
	my $sth;

	unless ( $sth = $this->{dbh}->prepare($sql) )
	{
		Everything::logErrors( '', "SQL failed: $sql [@$bound]\n" );
		return;
	}

	$sth->execute(@$bound) or do
	{
		local $" = '][';
		Everything::logErrors( '', "SQL failed: $sql [@$bound]\n" );
		return;
	};
}


sub getNodeByIdNew
{
	my ( $this, $node_id, $selectop ) = @_;
	my $cursor;
	my $NODE;

	$selectop ||= "";

	return $this->{nb}->getNodeZero() if ( $node_id == 0 );
	return unless $node_id;


	$cursor = $this->sqlSelectMany( "*", "node", "node_id=$node_id" );

	return unless $cursor;

	$NODE = $cursor->fetchrow_hashref();
	$cursor->finish();

	if ( $selectop ne "light" )
	  {

	      # OK, we have the hash from the 'node' table.  Now we need to
	      # construct the rest of the node.
	      $this->constructNode($NODE);
	  }

	return $NODE;
}


sub getNodeByName
{
	my ( $this, $node, $TYPE ) = @_;
	my $NODE;
	my $cursor;

	return unless ($TYPE);

	$this->{nb}->getRef($TYPE);

	$cursor = $this->sqlSelectMany( "*", "node",
		      "title="
			. $this->quote($node)
			. " AND type_nodetype="
			. $$TYPE{node_id} );

	return unless $cursor;

	$NODE = $cursor->fetchrow_hashref();
	$cursor->finish();

	return unless $NODE;

	# OK, we have the hash from the 'node' table.  Now we need to construct
	# the rest of the node.
	$this->constructNode($NODE);

	return $NODE;
}

=head2 C<constructNode>

Given a hash that contains a row of data from the 'node' table, get its type
and "join" on the appropriate tables.  This function is designed to work in
conjuction with simple queries that only search the node table, but then want a
complete node.  (ie do a search on the node table, find something, now we want
the complete node).

=over 4

=item * $NODE

the incomplete node that should be filled out.

=back

Returns true (1) if successful, false (0) otherwise.  If success, the node hash
passed in will now be a complete node.

=cut

sub constructNode
{
	my ( $this, $NODE ) = @_;
	my $cursor;
	my $DATA;
	my $tables = $this->getNodetypeTables( $$NODE{type_nodetype} );
	my $table;
	my $firstTable;
	my $tablehash;

	return unless ( $tables && @$tables > 0 );

	$firstTable = pop @$tables;

	foreach $table (@$tables)
	{
		$$tablehash{$table} = $firstTable . "_id=$table" . "_id";
	}

	$cursor =
		$this->sqlSelectJoined( "*", $firstTable, $tablehash,
		$firstTable . "_id=" . $$NODE{node_id} );

	return 0 unless ( defined $cursor );

	$DATA = $cursor->fetchrow_hashref();
	$cursor->finish();

	@$NODE{ keys %$DATA } = values %$DATA;

	# Make sure each field is at least defined to be nothing.
	foreach ( keys %$NODE )
	{
		$$NODE{$_} = "" unless defined( $$NODE{$_} );
	}

	$this->fix_node_keys($NODE);
	return 1;
}

=head2 C<selectNodeWhere>

Retrieves node ids that match the given query.

=over 4

=item * $WHERE

a hash reference to fieldname/value pairs on which to restrict the select or a
plain text WHERE string.

=item * $TYPE

the nodetype to search.  If this is not given, this will only search the fields
on the "node" table since without a nodetype we don't know what other tables to
join on.

=item * $orderby

the field in which to order the results.

=item * $limit

a limit to the max number of rows returned

=item * $offset

(only if limit is provided) offset from the start of the matched rows.  By
using this an limit, you can retrieve a specific range of rows.

=item * $refTotalRows

if you want to know the total number of rows that match the query, pass in a
ref to a scalar (ie: \$totalrows) and it will be set to the total rows that
match the query.  This is really only useful when specifying a limit.

=item * $nodeTableOnly

(performance enhancement) Set to 1 (true) if the search fields are only in the
node table.  This prevents the database from having to do table joins when they
are not needed.

=back

Returns a reference to an array that contains the node ids that match.  Undef
if no matches.

=cut

sub selectNodeWhere
{
	my ( $this, $WHERE, $TYPE, $orderby, $limit, $offset, $refTotalRows,
		$nodeTableOnly )
		= @_;

	$TYPE = undef if defined $TYPE && $TYPE eq '';

	# The caller wishes to know the total number of matches.
	$$refTotalRows = $this->countNodeMatches( $WHERE, $TYPE ) if $refTotalRows;

	my $cursor =
		$this->getNodeCursor( 'node_id', $WHERE, $TYPE, $orderby, $limit,
		$offset, $nodeTableOnly );

	return unless $cursor and $cursor->execute();

	my @nodelist;
	while ( my $node_id = $cursor->fetchrow() )
	{
		push @nodelist, $node_id;
	}

	$cursor->finish();

	return unless @nodelist;
	return \@nodelist;
}

=head2 C<getNodeCursor>

This returns the sql cursor for node matches.  Users of this object can call
this directly for specific searches, but the more general functions
selectNodeWhere() and getNodeWhere() should be used for most cases.

=over 4

=item * $select

The fields to select.  "*" for all, or provide a string of comma delimited
fields.

=item * $WHERE

a hash reference to fieldname/value pairs on which to restrict the select or a
plain text WHERE string.

=item * $TYPE

the nodetype to search.  If this is not given, this will only search the fields
on the "node" table since without a nodetype we don't know what other tables to
join on.

=item * $orderby

the field in which to order the results.

=item * $limit

a limit to the max number of rows returned

=item * $offset

(only if limit is provided) offset from the start of the matched rows.  By
using this an limit, you can retrieve a specific range of rows.

=item * $nodeTableOnly

(performance enhancement) Set to 1 (true) if the search fields are only in the
node table.  This prevents the database from having to do table joins when they
are not needed.  Note that if this is turned on you will not get "complete"
nodes, just the data from the "node" table.

=back

Returns the sql cursor from the "select".  undef if there was an error in the
search or no matches.  The caller is responsible for calling finish() on the
cursor.

=cut

sub getNodeCursor
{
	my ( $this, $select, $WHERE, $TYPE, $orderby, $limit, $offset,
		$nodeTableOnly )
		= @_;
	my $cursor;
	my $tablehash;

	$nodeTableOnly ||= 0;

	# Make sure we have a nodetype object
	$TYPE = $this->{nb}->getType($TYPE);

	my $wherestr = $this->genWhereString( $WHERE, $TYPE );

	# We need to generate an sql join command that has the potential
	# to join on multiple tables.  This way the SQL engine does the
	# search for us.

	# Now we need to join on the appropriate tables.
	if ( not $nodeTableOnly && defined $TYPE )
	{
		my $tableArray = $this->getNodetypeTables($TYPE);
		my $table;

		if ($tableArray)
		{
			foreach $table (@$tableArray)
			{
				$$tablehash{$table} = "node_id=" . $table . "_id";
			}
		}
	}

	my $extra;
	$extra .= "ORDER BY $orderby" if $orderby;
	$extra .= " " . $this->genLimitString( $offset, $limit ) if $limit;

	# Trap for SQL errors!
	my $warn;
	my $error;
	local $SIG{__WARN__} = sub {
		$warn .= $_[0];
	};
	eval {
		$cursor =
			$this->sqlSelectJoined( $select, "node", $tablehash, $wherestr,
			$extra );
	};
	$error = $@;
	local $SIG{__WARN__} = sub { };

	if ( $error ne "" or $warn ne "" )
	{
		Everything::logErrors( $warn, $error, "$select\n($TYPE)" );
		return;
	}

	return $cursor;
}

=head2 C<countNodeMatches>

Doing a full query has some extra overhead.  If you just want
to know how many rows a certain query will match, call this.
It is much faster than doing a full query.

=over 4

=item * $WHERE

a hash that contains the criteria for the search or a plain WHERE text string.

=item * $TYPE

the type of nodes this search is for.  If this is not provided, it will only do
the search on the node table.

=back

Returns the number of matches found.

=cut

sub countNodeMatches
{
	my ( $this, $WHERE, $TYPE ) = @_;
	my $cursor  = $this->getNodeCursor( 'count(*)', $WHERE, $TYPE );
	my $matches = 0;

	if ( $cursor && $cursor->execute() )
	{
		($matches) = $cursor->fetchrow();
		$cursor->finish();
	}

	return $matches;
}

=head2 C<getAllTypes>

This returns an array that contains all of the nodetypes in the system.  Useful
for knowing what nodetypes exist.

Returns an array of TYPE hashes of all the nodetypes in the system

=cut

sub getAllTypes
{
	my ($this) = @_;

	my $cursor = $this->sqlSelectMany( 'node_id', 'node', 'type_nodetype=1' );
	return unless $cursor;

	my @allTypes;

	while ( my ($node_id) = $cursor->fetchrow() )
	{
		push @allTypes, $this->{nb}->getNode($node_id);
	}

	$cursor->finish();

	return @allTypes;
}

=head2 C<getNodetypeTables>

Returns an array of all the tables that a given nodetype joins on.
This will create the array, if it has not already created it.

=over 4

=item * TYPE

The string name or integer Id of the nodetype

=item * addnode

if true, add 'node' to list.  Defaults to false.

=back

Returns a reference to an array that contains the names of the tables to join
on.  If the nodetype does not join on any tables, the array is empty.

=cut

sub getNodetypeTables
{
	my ( $this, $TYPE, $addNode ) = @_;
	my @tablelist;

	return unless $TYPE;

	# We need to short circuit on nodetype and nodemethod, otherwise we
	# get inf recursion.
	if ( ( $TYPE eq '1' ) or ( ( ref $TYPE ) && ( $TYPE->{node_id} == 1 ) ) )
	{
		push @tablelist, 'nodetype';
	}
	elsif ( ref $TYPE && $TYPE->{title} eq 'nodemethod' )
	{
		push @tablelist, 'nodemethod';
	}
	else
	{
		$this->{nb}->getRef($TYPE);
		my $tables = $TYPE->getTableArray();
		push @tablelist, @$tables if $tables;
	}

	push @tablelist, 'node' if $addNode;

	return \@tablelist;
}

=head2 C<dropNodeTable>

Drop (delete) a table from the database.  Note!!! This is permanent!  You will
lose all data in that table.

=over 4

=item * $table

the name of the table to drop.

=back

Returns 1 if successful, 0 otherwise.

=cut

sub dropNodeTable
{
	my ( $this, $table ) = @_;

	# These are the tables that we don't want to drop.  Dropping one
	# of these could cause the entire system to break.  If you really
	# want to drop one of these, do it from the command line.
	my $nodrop = {
		map { $_ => 1 }
			qw(
			container document htmlcode htmlpage image links maintenance node
			nodegroup nodelet nodetype note rating user
			)
	};

	if ( exists $nodrop->{$table} )
	{
		Everything::logErrors( '', "Attempted to drop core table '$table'!" );
		return 0;
	}

	return 0 unless $this->tableExists($table);

	Everything::printLog("Dropping table '$table'");
	return $this->{dbh}->do( "drop table " . $this->genTableName($table) );
}

=head2 C<quote>

A quick access to DBI's quote function for quoting strings so that they do not
affect the sql queries.

=over 4

=item * $str

the string to quote

=back

Returns the quoted string.

=cut

sub quote
{
	my ( $this, $str ) = @_;

	return $this->{dbh}->quote($str);
}

=head2 C<genWhereString>

This code was stripped from selectNodeWhere.  This takes a WHERE hash and a
string for ordering and generates the appropriate where string to pass along
with a select-type sql command.  The code is in this function so we can re-use
it. Note that this function takes less parameters than it used to, and doesn't
add the 'WHERE' to the beginning of the returned string.

You will note that this is not a full-featured WHERE generator -- there is no
way to do "field1=foo OR field2=bar" you can only OR on the same field and AND
on different fields I haven't had to worry about it yet.  That day may come

=over 4

=item * $WHERE

a reference to a hash that contains the criteria (ie title =E<gt> 'the node',
etc) or a string 'title="thenode"' or a plain text WHERE clause.  Note that it
should be quoted, if necessary, before passed in here.

=item * $TYPE

a hash reference to the nodetype

=back

Returns	a string that can be used for the sql query.

=cut

sub genWhereString
{
	my ( $this, $WHERE, $TYPE ) = @_;
	my $wherestr = "";
	my $tempstr;

	if ( ref $WHERE eq "HASH" )
	{
		foreach my $key ( keys %$WHERE )
		{
			$tempstr = "";

			# if your where hash includes a hash to a node, you probably really
			# want to compare the ID of the node, not the hash reference.
			if ( eval { $WHERE->{$key}->isa('Everything::Node') } )
			{
				$$WHERE{$key} = $this->{nb}->getId( $WHERE->{$key} );
			}

			# If $key starts with a '-', it means it's a single value.
			if ( $key =~ /^\-/ )
			{
				$key =~ s/^\-//;
				$tempstr .= $key . '=' . $$WHERE{ '-' . $key };
			}
			else
			{

				#if we have a list, we join each item with ORs
				if ( ref( $$WHERE{$key} ) eq "ARRAY" )
				{
					my $LIST  = $$WHERE{$key};
					my $orstr = "";

					foreach my $item (@$LIST)
					{
						$orstr .= " or " if ( $orstr ne "" );
						$item = $this->{nb}->getId($item);
						$orstr .= $key . '=' . $this->quote($item);
					}

					$tempstr .= "(" . $orstr . ")";
				}
				elsif ( defined $$WHERE{$key} )
				{
					$tempstr .= $key . '=' . $this->quote( $$WHERE{$key} );
				}
			}

			if ( $tempstr ne "" )
			{

				#different elements are joined together with ANDS
				$wherestr .= " AND \n" if ( $wherestr ne "" );
				$wherestr .= $tempstr;
			}
		}
	}
	else
	{
		$wherestr .= $WHERE || '';

		#note that there is no protection when you use a string
		#play it safe and use $dbh->quote, kids.
	}

	if ( defined $TYPE )
	{
		$wherestr .= " AND" if ( $wherestr ne "" );
		$wherestr .= " type_nodetype=" . $this->{nb}->getId($TYPE);
	}

	return $wherestr;
}


# override this to fix odd column names
sub fix_node_keys {}


=head2 C<parse_sql_file>

This is a utility method for Nodeball.pm. It takes an open filehandle
that should be open on a file of some raw sql perhaps dumped from a
database. The method, strips out comments and blank lines and splits the string
into seperate sql statements that can then be passed individually to
DBI.pm.

=over 4

=item * $fh

Takes an open filehandle.

=back

Returns a list of strings, that are SQL statements.

=cut

sub parse_sql_file {
    my ($self, $fh) = @_;
    my $sql = '';
    foreach (<$fh>) {
	next if /^#/;
	next if /^\//;
	next if /^\s*--/;
	next if /^\s*$/;
	$sql .= "$_";
	}
    my @statements = split /;\s*/, $sql;
    return @statements;

}


=head2 C<install_base_tables>

Installs the base tables into a new database.

=cut

sub install_base_tables {
    my $self = shift;
    
    foreach ( $self->base_tables() ) {
        $self->{dbh}->do($_);
        die($DBI::errstr) if $DBI::errstr;
    }


}


=head2 C<install_base_tables>

Installs the base tables into a new database.

=cut

sub install_base_nodes {
    my $self = shift;
    
    foreach ( $self->base_nodes() ) {
        $self->{dbh}->do($_);
        die("$_, $DBI::errstr") if $DBI::errstr;
    }
}



=head2 C<base_tables>

Returns a list of SQL statements necessary to insert the base nodes into a databse.

=cut

sub base_nodes {

    return (
q{INSERT INTO node VALUES (1,1,'nodetype',-1,'0000-00-00 00:00:00','0000-00-00 00:00:00',0,0,0,0,'0000-00-00 00:00:00','iiii','rwxdc','-----','-----',0,0,0,0,0)},
q{INSERT INTO node VALUES (2,1,'node',-1,'0000-00-00 00:00:00','0000-00-00 00:00:00',0,0,0,0,'0000-00-00 00:00:00','rwxd','-----','-----','-----',-1,-1,-1,-1,0)},
q{INSERT INTO node VALUES (3,1,'setting',-1,'0000-00-00 00:00:00','0000-00-00 00:00:00',0,0,0,0,'0000-00-00 00:00:00','rwxd','-----','-----','-----',0,0,0,0,0)},
q{INSERT INTO nodetype VALUES (1,0,2,1,'nodetype','','rwxd','rwxdc','-----','-----',0,0,0,0,0,-1,0)},
q{INSERT INTO nodetype VALUES (2,0,0,1,'','','rwxd','r----','-----','-----',0,0,0,0,0,1000,1)},
q{INSERT INTO nodetype VALUES (3,0,2,1,'setting','','rwxd','-----','-----','-----',0,0,0,0,0,-1,-1)},

      )

}

sub retrieve_column_info {

    my ( $self, $table_name, $column_name ) = @_;
    my $sth = $self->{dbh}->column_info( '', '', $table_name, $column_name );
    my $data = $sth->fetchrow_hashref;
    return $data;


}

1;
