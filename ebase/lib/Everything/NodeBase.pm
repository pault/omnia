
=head1 Everything::NodeBase

Wrapper for the Everything database and cache.  

Copyright 1999 - 2003 Everything Development Inc.

=cut

package Everything::NodeBase;

#	Format: tabs = 4 spaces

use strict;
use DBI;
use File::Spec;
use Everything ();
use Everything::NodeCache;
use Everything::Node;

=cut


=head2 C<new>

Constructor for this module

=over 4

=item * $dbname

the database name to connect to

=item * $staticNodetypes

a performance enhancement.  If the nodetypes in your system are fairly constant
(you are not changing their permissions dynamically or not manually changing
them often) set this to 1.  By turning this on we will derive the nodetypes
once and thus save that work each time we get a nodetype.  The downside to this
is that if you change a nodetype, you will need to restart your web server for
the change to take. 

=back

Returns a new NodeBase object

=cut

sub new
{
	my ( $class, $db, $staticNodetypes ) = @_;

	my ( $dbname, $user, $pass, $host ) = split /:/, $db;
	$user ||= 'root';
	$pass ||= '';
	$host ||= 'localhost';

	my $this = bless {}, $class;

	$this->databaseConnect( $dbname, $host, $user, $pass );

	$this->{cache}           = Everything::NodeCache->new( $this, 300 );
	$this->{dbname}          = $dbname;
	$this->{nodetypeModules} = $this->buildNodetypeModules();
	$this->{staticNodetypes} = $staticNodetypes ? 1 : 0;

	if ( $this->getType('setting') )
	{
		my $CACHE     = $this->getNode( 'cache settings', 'setting' );
		my $cacheSize = 300;

		# Get the settings from the system
		if ( defined $CACHE && UNIVERSAL::isa( $CACHE, 'Everything::Node' ) )
		{
			my $vars = $CACHE->getVars();
			$cacheSize = $vars->{maxSize} if exists $vars->{maxSize};
		}

		$this->{cache}->setCacheSize($cacheSize);
	}

	return $this;
}

=cut


=head2 C<joinWorkspace>

create the $DB-E<gt>{workspace} object if a workspace is specified.  If the
sole parameter is 0, then the workspace is deleted.

=over 4

=item * WORKSPACE

workspace_id, node, or 0 for none

=back

=cut

sub joinWorkspace
{
	my ( $this, $WORKSPACE ) = @_;

	delete $this->{workspace} if exists $this->{workspace};

	return 1 unless $WORKSPACE;

	$this->getRef($WORKSPACE);
	return -1 unless $WORKSPACE;
	$this->{workspace} = $WORKSPACE;
	$this->{workspace}{nodes} = $WORKSPACE->getVars;
	$this->{workspace}{nodes} ||= {};
	$this->{workspace}{cached_nodes} = {};

	1;
}

=cut


=head2 C<getNodeWorkspace>

Helper funciton for getNode's workspace functionality.  Given a $WHERE hash (
field =E<gt> value, or field =E<gt> [value1, value2, value3]) return a list of
nodes in the workspace which fullfill this query

=over 4

=item * $WHERE

where hash, similar to getNodeWhere

=item * $TYPE

type discrimination (optional)

=back

=cut

sub getNodeWorkspace
{
	my ( $this, $WHERE, $TYPE ) = @_;
	my @results;
	$TYPE = $this->getType($TYPE) if $TYPE;

	my $cmpval = sub {
		my ( $val1, $val2 ) = @_;

		$val1 = $val1->{node_id} if UNIVERSAL::isa( $val1, 'Everything::Node' );
		$val2 = $val2->{node_id} if UNIVERSAL::isa( $val2, 'Everything::Node' );

		$val1 eq $val2;
	};

	#we need to iterate through our workspace
	foreach my $node ( keys %{ $this->{workspace}{nodes} } )
	{
		my $N = $this->getNode($node);
		next if $TYPE and $$N{type}{node_id} != $$TYPE{node_id};

		my $match = 1;
		foreach ( keys %$WHERE )
		{
			if ( ref $$WHERE{$_} eq 'ARRAY' )
			{
				my $matchor = 0;
				foreach my $orval ( @{ $$WHERE{$_} } )
				{
					$matchor = 1 if $cmpval->( $$N{$_}, $orval );
				}
				$match = 0 unless $matchor;
			}
			else
			{
				$match = 0 unless $cmpval->( $$N{$_}, $$WHERE{$_} );
			}
		}
		push @results, $N if $match;
	}

	\@results;
}

=cut


=head2 C<rebuildNodetypeModules>

Call this to account for any new nodetypes that may have been installed.
Primarily used by nbmasta when installing a new nodeball.

=cut

sub rebuildNodetypeModules
{
	my ($this) = @_;

	$this->{nodetypeModules} = $this->buildNodetypeModules();

	return;
}

=cut


=head2 C<buildNodetypeModules>

Perl 5.6 throws errors if we test "can" on a non-existing module.  This
function builds a hashref with keys to all of the modules that exist in the
Everything::Node:: dir This also casts "use" on the modules, loading them into
memory

=cut

sub buildNodetypeModules
{
	my ($this) = @_;

	my $csr = $this->sqlSelectMany( 'title', 'node', 'type_nodetype=1' );
	return unless $csr;

	my %modules;

	while ( my ($title) = $csr->fetchrow_array() )
	{
		$title =~ s/\W//g;
		my $modname = "Everything::Node::$title";

		$modules{$modname} = 1 if $this->loadNodetypeModule($modname);
	}

	return \%modules;
}

sub loadNodetypeModule
{
	my ( $self, $modname ) = @_;
	( my $modpath = $modname . '.pm' ) =~ s!::!/!g;

	return 1 if exists $INC{$modpath};

	foreach my $path (@INC)
	{
		next
			unless -e File::Spec->canonpath(
			File::Spec->catfile( $path, $modpath ) );
		last if eval { require $modpath };
	}

	Everything::logErrors( '', "Using '$modname' gave errors: '$@'" )
		if $@ and $@ !~ /Can't locate/;

	return exists $INC{$modpath};
}

=cut


=head2 C<resetNodeCache>

The node cache holds onto nodes after they have been loaded from the database.
When a node is requested, it checks to see if it has the node in its cache.  If
it does, the cache will see if the version of the node is the same as what is
in the database.  This version check is done *once* to save hits to the
database.  If you want the cache to recheck the versions, call this function.

=cut

sub resetNodeCache
{
	my ($this) = @_;

	$this->{cache}->resetCache();
}

=cut


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

=cut


=head2 C<getCache>

This returns the NodeCache object that we are using to cache nodes.  In
general, you should never need to access the cache directly.  This is more for
maintenance type stuff (you want to check the cache size, etc).

Returns a reference to the NodeCache object

=cut

sub getCache
{
	my ($this) = @_;

	return $this->{cache};
}

=cut


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

=cut


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

=cut


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
	my ( $this, $select, $table, $joins, $where, $other, @bound ) = @_;

	my $sql = "SELECT $select ";
	$sql .= "FROM " . $this->genTableName($table) . " " if $table;

	while ( my ( $join, $column ) = each %$joins )
	{
		$sql .= "LEFT JOIN " . $this->genTableName($join) . " ON $column ";
	}

	$sql .= "WHERE $where " if $where;
	$sql .= $other          if $other;

	my $cursor = $this->{dbh}->prepare($sql) or return;

	$cursor->execute(@bound) or return;
	return $cursor;
}

=cut


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

=cut


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

=cut


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

=cut


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

	return $this->sqlExecute( $sql, $bound );
}

=cut


C<_quoteData>

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

=cut


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
	};
}

#############################################################################
#	TEMPORARY WRAPPER!
sub getNodeById
{
	my ( $this, $node_id, $selectop ) = @_;

	return $this->getNode( $node_id, $selectop );
}

=cut


=head2 C<newNode>

A more programatically "graceful" way than getNode() to get a node that does
not exist in the database.  This is primarily use when creating new nodes or
needing a node object that just has methods that you wish to call.

=over 4

=item * $type

a nodetype name, id, or Node object of the type of node to create

=item * $title

(optional) the title of the node

=back

Returns the new node.  Note that this node is not in the database.  If you want
to save it to the database, you will need to call insert() on it.

=cut

sub newNode
{
	my ( $this, $type, $title ) = @_;

	$title ||= "dummy" . int( rand(1000000) );
	$type = $this->getType($type);

	return $this->getNode( $title, $type, 'create force' );
}

=cut


=head2 C<getNode>

This is the one and only function needed to get a single node.  If any function
other than getNode() is used, the system will not work properly.

This function has two forms.  One form is for getting a node by its id, the
other is for getting the node by its title and type.  Note that if duplicate
titles are allowed for the nodetype, this will only get the first one that it
finds in the database.

=over 4

=item * $node

either the string title, node id, NODE object, or "where hash ref".  The NODE
object is just for ease of use, so you can call this function without worrying
if the node thingy is an ID or object.  If this is a where hash ref, this
simply does a getNodeWhere() and returns the first match only (just a quicky
way of doing a getNodeWhere())

=item * $ext

extra info.  If $node is a string title, this must be either a hashref to a
nodetype node, or a nodetype id.  If $node is an id, $ext is optional and can
be either 'light' or 'force'.  If 'light' it will retrieve only the information
from the node table (faster).  If 'force', it will reload the node even if it
is cached.

=item * $ext2

more extra info.  If this is a "title/type" query, passing 'create' will cause
a dummy object to be created and returned if a node is not found.  Using the
dummy node, you can then add or modify its fields and then do a
$NODE-E<gt>insert($USER) to insert it into the database.  If you wish to create
a node even if a node of the same "title/type" exists, pass "create force".  A
dummy node has a node_id of '-1'.

If $node is a "where hash ref", this is the "order by" string that you can pass
to order the result by (you will still only get one node).

=back

Returns a node object if successful.  undef otherwise.

=cut

sub getNode
{
	my ( $this, $node, $ext, $ext2 ) = @_;
	return unless defined $node and $node ne '';

	# it may already be a node
	return $node if UNIVERSAL::isa( $node, 'Everything::Node' );

	my $NODE;
	my $cache = "";

	if ( ref $node eq 'HASH' )
	{

		# This a "where" select
		my $nodeArray = $this->getNodeWhere( $node, $ext, $ext2, 1 ) || [];
		if ( exists $this->{workspace} )
		{
			my $wspaceArray = $this->getNodeWorkspace( $node, $ext );

			#the nodes we get back are unordered, must be merged
			#with the workspace.  Also any nodes which were in the
			#nodearray, and the workspace, but not the wspace array
			#must be removed

			my @results = (
				(
					grep { !exists $this->{workspace}{nodes}{ $_->{node_id} } }
						@$nodeArray
				),
				@$wspaceArray
			);

			return unless @results;
			my $orderby = $ext2 || 'node_id';

			my $position = ( $orderby =~ /\s+desc/i ) ? -1 : 0;

			@results = sort { $a->{$orderby} cmp $b->{$orderby} } @results;
			return $results[$position];
			return shift @results;
		}
		else
		{
			return $nodeArray->[0] if @$nodeArray;
			return;
		}
	}
	elsif ( $node =~ /^\d+$/ )
	{
		$NODE = $this->getNodeByIdNew( $node, $ext );
		$cache = "nocache" if ( defined $ext && $ext eq 'light' );
	}
	else
	{
		$ext = $this->getType($ext);

		$ext2 ||= "";
		if ( $ext2 ne "create force" )
		{
			$NODE = $this->getNodeByName( $node, $ext );
		}

		if (   ( $ext2 eq "create force" )
			or ( $ext2 eq "create" && ( not defined $NODE ) ) )
		{

			# We need to create a dummy node for possible insertion!
			# Give the dummy node pemssions to inherit everything
			$NODE = {
				node_id                  => -1,
				title                    => $node,
				type_nodetype            => $this->getId($ext),
				authoraccess             => 'iiii',
				groupaccess              => 'iiiii',
				otheraccess              => 'iiiii',
				guestaccess              => 'iiiii',
				group_usergroup          => -1,
				dynamicauthor_permission => -1,
				dynamicgroup_permission  => -1,
				dynamicother_permission  => -1,
				dynamicguest_permission  => -1,
			};

			# We do not want to cache dummy nodes
			$cache = "nocache";
		}
	}

	return unless $NODE;

	$NODE = Everything::Node->new( $NODE, $this, $cache );

	if (    exists $this->{workspace}
		and exists $this->{workspace}{nodes}{ $NODE->{node_id} }
		and $this->{workspace}{nodes}{ $NODE->{node_id} } )
	{
		my $WS = $NODE->getWorkspaced();
		return $WS if $WS;
	}

	return $NODE;
}

#############################################################################
sub getNodeByName
{
	my ( $this, $node, $TYPE ) = @_;
	my $NODE;
	my $cursor;

	return unless ($TYPE);

	$this->getRef($TYPE);

	$NODE = $this->{cache}->getCachedNodeByName( $node, $$TYPE{title} );
	return $NODE if ( defined $NODE );
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

=cut


=head2 C<getNodeZero>

The node with zero as its ID is a "dummy" node that represents the root
location of the system.  Think of this as the "/" (root directory) on unix.
Only gods have access to this node.

Note: this is just a "dummy" node.  It does not exist in the database.

Returns the "Zero Node".

=cut

sub getNodeZero
{
	my ($this) = @_;
	unless ( exists $$this{nodezero} )
	{
		$$this{nodezero} = $this->getNode( "/", "location", "create force" );

		$$this{nodezero}{node_id} = 0;

		$$this{nodezero}{guestaccess} = "-----";
		$$this{nodezero}{otheraccess} = "-----";
		$$this{nodezero}{groupaccess} = "-----";
		$$this{nodezero}{author_user} = $this->getNode( "root", "user" );
	}

	return $$this{nodezero};
}

#############################################################################
sub getNodeByIdNew
{
	my ( $this, $node_id, $selectop ) = @_;
	my $cursor;
	my $NODE;

	$selectop ||= "";

	return $this->getNodeZero() if ( $node_id == 0 );
	return unless $node_id;

	if ( $selectop ne "force" )
	{
		$NODE = $this->{cache}->getCachedNodeById($node_id);
	}

	if ( not defined $NODE )
	{
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
	}

	return $NODE;
}

=cut


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

=cut


=head2 C<getNodeWhere>

Get a list of NODE hashes.  This constructs a complete node.

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

the maximum number of rows to return

=item * $offset

(only if limit is provided) offset from the start of the matched rows.  By
using this an limit, you can retrieve a specific range of rows.

=item * $refTotalRows

if you want to know the total number of rows that match the query, pass in a
ref to a scalar (ie: \$totalrows) and it will be set to the total rows that
match the query.  This is really only useful when specifying a limit.

=back

Returns a reference to an array that contains nodes matching the criteria or
undef, if the operation fails

=cut

sub getNodeWhere
{
	my $this = shift;

	my $selectNodeWhere = $this->selectNodeWhere(@_);

	return
		unless defined $selectNodeWhere
		and UNIVERSAL::isa( $selectNodeWhere, 'ARRAY' );

	my @nodelist;

	foreach my $node ( @{$selectNodeWhere} )
	{
		my $NODE = $this->getNode($node);
		push @nodelist, $NODE if $NODE;
	}

	return \@nodelist;
}

=cut


=head2 C<selectNodeWhere>

Retrieves node id's that match the given query.

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

=cut


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
	$TYPE = $this->getType($TYPE);

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
	eval
	{
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

=cut


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

=cut


=head2 C<getType>

This is just a quickie wrapper to get a nodetype by name or id.  Saves extra
typing.

Returns a hash ref to a nodetype node.  undef if not found

=cut

sub getType
{
	my ( $this, $idOrName ) = @_;

	return unless defined $idOrName and $idOrName ne '';

	# The thing they passed in is good to go.
	return $idOrName if UNIVERSAL::isa( $idOrName, 'Everything::Node' );

	return $this->getNode( $idOrName, 1 ) if $idOrName =~ /\D/;
	return $this->getNode($idOrName) if $idOrName > 0;
	return;
}

=cut


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
		push @allTypes, $this->getNode($node_id);
	}

	$cursor->finish();

	return @allTypes;
}

=cut


=head2 C<getFields>

Get the field names of a table.

=over 4

=item * $table

the name of the table of which to get the field names

=back

Returns an array of field names

=cut

sub getFields
{
	my ( $this, $table ) = @_;

	return $this->getFieldsHash( $table, 0 );
}

=cut


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

=cut


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

=cut


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
			if ( UNIVERSAL::isa( $WHERE->{$key}, 'Everything::Node' ) )
			{
				$$WHERE{$key} = $this->getId( $WHERE->{$key} );
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
						$item = $this->getId($item);
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
		$wherestr .= $WHERE;

		#note that there is no protection when you use a string
		#play it safe and use $dbh->quote, kids.
	}

	if ( defined $TYPE )
	{
		$wherestr .= " AND" if ( $wherestr ne "" );
		$wherestr .= " type_nodetype=" . $this->getId($TYPE);
	}

	return $wherestr;
}

#############################################################################
#	"Private" functions to this module
#############################################################################

=cut


C<getNodetypeTables>

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
	if ( ( $TYPE eq "1" ) or ( ( ref $TYPE ) && ( $$TYPE{node_id} == 1 ) ) )
	{
		push @tablelist, "nodetype";
	}
	elsif ( ref $TYPE && $$TYPE{title} eq "nodemethod" )
	{
		push @tablelist, "nodemethod";
	}
	else
	{
		$this->getRef($TYPE);
		my $tables = $TYPE->getTableArray();
		push @tablelist, @{$tables} if ($tables);
	}

	push @tablelist, 'node' if ($addNode);

	return \@tablelist;
}

=cut


C<getRef>

This makes sure that we have an array of node hashes, not node id's.

Returns the node hash of the first element passed in.

=cut

sub getRef
{
	my $this = shift;
	local $_;

	for (@_)
	{
		next if UNIVERSAL::isa( $_, 'Everything::Node' );
		$_ = $this->getNode($_) if defined $_;
	}

	return $_[0];
}

=cut


C<getId>

Given a node object or a node id, return the id.  Just a quick function to call
to make sure that you have an id.

=over 4

=item * node

a node object or a node id

=back

Returns the node id.  undef if not able to obtain an id.

=cut

sub getId
{
	my ( $this, $node ) = @_;

	return unless $node;
	return $node->{node_id} if UNIVERSAL::isa( $node, 'Everything::Node' );
	return $node if $node =~ /^-?\d+$/;
	return;
}

=cut


=head2 C<hasPermission>

This does dynamic permission calculations using the specified
permissions node.  The permissions node contains code that will
calculate what permissions a user has.  For example, if a user
has certain flags on, the code may enable or disable write
permissions.  This is also a great way of abstracting permissions
and assigning them to actions.  In your code you can say

  if(hasPermission($USER, undef, 'allow vote', "x")
  {
	... show voting stuff ...
  }

The code in 'allow vote' could be something like:

  return "x" if($$USER{experience} > 100)
  return "-";

=over 4

=item * $USER

the user that we want to check for access.

=item * $permission

the name of the permission node that contains the code we want to run.

=item * $modes

what modes are necessary

=back

Returns 1 (true), if the user has the needed permissions, 0 (false) otherwise

=cut

sub hasPermission
{
	my ( $this, $USER, $permission, $modes ) = @_;
	my $PERM = $this->getNode( $permission, 'permission' );

	return 0 unless $PERM;

	my $perms = eval $PERM->{code};

	return Everything::Security::checkPermissions( $perms, $modes );
}

# if the database returns odd column names, override this to fix them
sub fix_node_keys { }

#############################################################################
#	DEPRECATED - use hasAccess()
sub canCreateNode
{
	my ( $this, $USER, $TYPE ) = @_;
	return $this->hasAccess( $TYPE, $USER, "c" );
}

#############################################################################
#	DEPRECATED - use hasAccess()
sub canDeleteNode
{
	my ( $this, $USER, $NODE ) = @_;
	return $this->hasAccess( $NODE, $USER, "d" );
}

#############################################################################
#	DEPRECATED - use hasAccess()
sub canUpdateNode
{
	my ( $this, $USER, $NODE ) = @_;
	return $this->hasAccess( $NODE, $USER, "w" );
}

#############################################################################
#	DEPRECATED - use hasAccess()
sub canReadNode
{
	my ( $this, $USER, $NODE ) = @_;
	return $this->hasAccess( $NODE, $USER, "r" );
}

#############################################################################
#	End of Package
#############################################################################

1;