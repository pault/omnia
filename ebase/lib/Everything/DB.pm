
=head1 Everything::DB

Wrapper for the Everything database.

Copyright 2006 Everything Development Inc.

=cut

package Everything::DB;

use strict;
use warnings;

use Moose;

has dbname => ( is => 'rw' );

use DBI;
use Everything::DB::Node;
use Scalar::Util qw/blessed reftype/;

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

	$bound ||= [];
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

	my $cursor = $this->{dbh}->prepare($sql) or do { warn "WARNING SQL FAILED: $sql"; return; };

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
		Everything::logErrors( '', "SQL failed: $sql [@$bound]\n" . DBI->errstr );
		return;
	}
	$sth->execute(@$bound) or do
	{
		local $" = '][';
		Everything::logErrors( '', "SQL failed: $sql [@$bound]\n" . DBI->errstr );
		return;
	};
}


sub getNodeByIdNew
{
	my ( $this, $node_id, $selectop ) = @_;
	my $cursor;
	my $NODE;

	$selectop ||= "";

	if ( $node_id == 0 ) {

	    return +{
		     node_id                  => 0,
		     title                    => '/',
		     type_nodetype            => 2,
		     authoraccess             => 'iiii',
		     groupaccess              => '-----',
		     otheraccess              => '-----',
		     guestaccess              => '-----',
		    };


	}
	return unless $node_id;


	$cursor = $this->sqlSelectMany( "*", "node", "node_id=$node_id" );

	return unless $cursor;

	$NODE = $cursor->fetchrow_hashref();
	$cursor->finish();

	return unless $NODE;

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
	my ( $this, $node, $nodetype_title ) = @_;
	my $NODE;
	my $cursor;


	## I don't like this behaviour. If we fail to pass a required
	## argument we should 'die'.
	return unless ($nodetype_title);

	my $type_data = $this->nodetype_data_by_name( $nodetype_title );

	# Now we have the nodetype, we can start to construct the
	# node, because we can call the nodetype sql/perl to make it.
	$cursor = $this->sqlSelectMany( "*", "node",
		      "title="
			. $this->quote($node)
			. " AND type_nodetype="
			. $$type_data{node_id} );

	return unless $cursor;

	$NODE = $cursor->fetchrow_hashref();
	$cursor->finish();

	return unless $NODE;

	# OK, we have the hash from the 'node' table.  Now we need to construct
	# the rest of the node.
	$this->constructNode($NODE);

	return $NODE;
}

=head2 purge_node_data

Removes all the data related to a node.  Passed a node object as its argument.

=cut

sub purge_node_data {

    my ( $self, $node ) = @_;

    my $result;

    my $id = $node->getId;

    my $tableArray = $self->retrieve_nodetype_tables( $node->get_type_nodetype, 1);

	foreach my $table (@$tableArray)
	{
		$result += $self->sqlDelete( $table, "${table}_id = ?", [$id] );
	}

    return $result;
}

sub nodetype_data_by_name {

    my ( $self, $typename ) = @_;

    my $dbh = $self->getDatabaseHandle;

    my $sth = $dbh->prepare_cached( 'SELECT * FROM node LEFT JOIN nodetype ON node.node_id = nodetype.nodetype_id WHERE node.title = ? ' );
 
    $sth->execute( $typename );

    my $data = $sth->fetchrow_hashref;



    $sth->finish;

    return $data;

}

sub nodetype_data_by_id {

    my ( $self, $id ) = @_;

    my $dbh = $self->getDatabaseHandle;
    my $sth;

    $sth = $dbh->prepare_cached( 'SELECT * FROM node LEFT JOIN nodetype ON node.node_id = nodetype.nodetype_id WHERE node.node_id = ? ' );

    $sth->execute( $id );

    my $data = $sth->fetchrow_hashref;

    $sth->finish;

    return $data;

}

=head2 nodetype_hierarchy_by_id

Returns a array ref of hash refs of a nodetype hierarchy.  The first
item in the array pointed to by the return value will be the nodetype
identified by the single argument.

Takes one argument, the identifier of the nodetype for which a
hierarchy is required.

=cut

sub nodetype_hierarchy_by_id {

    my ( $self, $id ) = @_;

    my @nodetypes = ();
    my $type;

    while ( $id && ( $type = $self->nodetype_data_by_id($id)) ) {
	$id = $type->{extends_nodetype};
	push @nodetypes, $type;
    }

    return \@nodetypes if @nodetypes;
    return;
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

    return unless $NODE;

    my $constructor;

    $constructor = Everything::DB::Node->instantiate( db => $this, data =>  $NODE );

    $constructor->construct_node_data_from_hash( $NODE );

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

# XXXXXXXXXXX: as documented only searches the node table unless
# '$TYPE' is specified. If $TYPE is specified we can launch into
# proper deep search of the nodes based on custom SELECT statement or
# perl for each node.

# How to dispatch each nodetype query...could each dispatch be
# represented by a Everything::DB::Nodetype object that contains the
# nodetype node, the title and dispatches the request to DB.pm.

# Because nodetypes themselves are special, then how to get nodetypes
# themselves would have to be hard-coded into DB.pm or
# Nodebase.pm. It's a way of bootstrapping the node loading process.

# SELECT * from node, nodetype where node.node_id = nodetype.nodetype_id.

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

the identifier of nodetype to search, i.e. node_id or nodetype_id.  If
this is not given, this will only search the fields on the "node"
table since without a nodetype we don't know what other tables to join
on.

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

	# Because of the legacy, $TYPE might be a nodetype node, a
	# node id, or a nodetype title.  Let's sort this out before we
	# go any further.

	my $wherestr = $this->genWhereString( $WHERE, $TYPE );

	# We need to generate an sql join command that has the potential
	# to join on multiple tables.  This way the SQL engine does the
	# search for us.

	# Now we need to join on the appropriate tables.
	if ( not $nodeTableOnly && defined $TYPE )
	{
		my $tableArray = $this->getNodetypeTables($TYPE);

		if ($tableArray)
		{
			foreach my $table (@$tableArray)
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

=head2 C<retrieve_nodetype_tables>

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

sub retrieve_nodetype_tables {

    my ( $self, $type_id, $add_node ) = @_;

    my $types = $self->nodetype_hierarchy_by_id ( $type_id );

    return $self->derive_sqltables( $types, $add_node );
}

sub derive_sqltables {

    shift;
    my ( $types, $add_node ) = @_;

    my @tables = ();

    push @tables, split ',',  $_->{sqltable} || '' foreach @$types;

    push @tables, 'node' if $add_node;

    return \@tables;


}

=head2 retrieve_group_table

Takes one argument: the id of the nodetype for which a group table is required.

Returns a string which is the name of the group table.

=cut

sub retrieve_group_table {

    my ( $self, $type_id ) = @_;

    my $types = $self->nodetype_hierarchy_by_id ( $type_id );

    return $self->derive_grouptable ( $types );

}

sub derive_grouptable {

    shift;
    my $types = shift;
    my $table;
    foreach ( @$types ) {
	last if $table  = $_->{grouptable};
    }

    return $table;

}


# XXXX: this method hasn't got a POD, and I'm not sure I want to give
# it one. The problem is the $TYPE argument, which can be a nodetype,
# a name or a node_id.  It is just awful to do this. We should know
# what we have a call it appropriately.

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

	    if ( reftype $TYPE ) {

		my $tables = $this->retrieve_nodetype_tables( $$TYPE{node_id} );
		push @tablelist, @$tables if $tables;

	    } else {
		    my $tables = $this->retrieve_nodetype_tables( $TYPE );
		    push @tablelist, @$tables if $tables;

	    }


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
				$$WHERE{$key} = $WHERE->{$key}->{node_id};
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
						if ( blessed( $item ) && $item->isa('Everything::Node') ) { 
						    $item = $item->{node_id};
						}

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
		if ( blessed( $TYPE ) && $TYPE->isa('Everything::Node') ) {
		    $wherestr .= " type_nodetype=" . $TYPE->{node_id};
		} elsif ( my $data = $this->nodetype_data_by_name( $TYPE ) ) {

		    $wherestr .= " type_nodetype=" . $$data{nodetype_id};
		} else {
		    $wherestr .= " type_nodetype=" . $TYPE; # assume we have a node_id
		}
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
q{INSERT INTO node VALUES (1,1,'nodetype',NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',0,0,'0000-00-00 00:00:00','iiii','rwxdc','-----','-----',0,0,0,0,0)},
q{INSERT INTO node VALUES (2,1,'node',-1,'0000-00-00 00:00:00','0000-00-00 00:00:00',0,0,'0000-00-00 00:00:00','rwxd','-----','-----','-----',NULL,NULL,NULL,NULL,0)},
q{INSERT INTO node VALUES (3,1,'setting',NULL,'0000-00-00 00:00:00','0000-00-00 00:00:00',0,0,'0000-00-00 00:00:00','rwxd','-----','-----','-----',0,0,0,0,0)},
q{INSERT INTO nodetype VALUES (1,0,2,1,'nodetype','','rwxd','rwxdc','-----','-----',0,0,0,0,0,NULL,0)},
q{INSERT INTO nodetype VALUES (2,0,0,1,'','','rwxd','r----','-----','-----',0,0,0,0,0,1000,1)},
q{INSERT INTO nodetype VALUES (3,0,2,1,'setting','','rwxd','-----','-----','-----',0,0,0,0,0,NULL,NULL)},
q{INSERT INTO node_statistics_type (type_name, description) VALUES ('hits', 'A value that represents how many times a node has been accessed.')},
q{INSERT INTO node_statistics_type (type_name, description) VALUES ('reputation', 'A value that represents the value of a node to the users.')},
      )

}

sub retrieve_column_info {

    my ( $self, $table_name, $column_name ) = @_;
    my $sth = $self->{dbh}->column_info( '', '', $table_name, $column_name );
    my $data = $sth->fetchrow_hashref;
    return $data;


}

1;
