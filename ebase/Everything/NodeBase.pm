package Everything::NodeBase;

#############################################################################
#	Everything::NodeBase
#		Wrapper for the Everything database and cache.  
#
#	Copyright 1999 - 2002 Everything Development Inc.
#	Format: tabs = 4 spaces
#
#############################################################################

use strict;
use DBI;
use Everything;
use Everything::NodeCache;
use Everything::Node;


#############################################################################
#	Sub
#		new
#
#	Purpose
#		Constructor for this module
#
#	Parameters
#		$dbname - the database name to connect to
#		$staticNodetypes - a performance enhancement.  If the nodetypes in
#			your system are fairly constant (you are not changing their
#			permissions dynamically or not manually changing them often) set
#			this to 1.  By turning this on we will derive the nodetypes
#			once and thus save that work each time we get a nodetype.  The
#			downside to this is that if you change a nodetype, you will need
#			to restart your web server for the change to take. 
#
#	Returns
#		A new NodeBase object
#
sub new
{
	my ($class, $db, $staticNodetypes) = @_;

	my ($dbname, $user, $pass, $host) = split /:/, $db;
	$user ||= 'root';
	$pass ||= '';
	$host ||= 'localhost';

	my $this = bless {}, $class;

	$this->databaseConnect($dbname, $host, $user, $pass);

	$this->{cache}           = Everything::NodeCache->new($this, 300);
	$this->{dbname}          = $dbname;
	$this->{nodetypeModules} = $this->buildNodetypeModules();
	$this->{staticNodetypes} = $staticNodetypes ? 1 : 0;

	if ($this->getType('setting'))
	{
		my $CACHE = $this->getNode('cache settings', 'setting');
		my $cacheSize = 300;

		# Get the settings from the system
		if (defined $CACHE && UNIVERSAL::isa( $CACHE, 'Everything::Node'))
		{
			my $vars   = $CACHE->getVars();
			$cacheSize = $vars->{maxSize} if exists $vars->{maxSize};
		}

		$this->{cache}->setCacheSize($cacheSize);
	}

	return $this;
}


#########################################################################
#
#	sub
#		joinWorkspace
#
#	purpose
#		create the $DB->{workspace} object if a workspace is specified.  If
#		the sole parameter is 0, then the workspace is deleted.
#
#	params 
#		WORKSPACE -- workspace_id, node, or 0 for none
#
sub joinWorkspace {
	my ($this, $WORKSPACE) = @_;
	
	delete $this->{workspace} if exists $this->{workspace};
    if ($WORKSPACE == 0) {
		return 1;
	}

	$this->getRef($WORKSPACE);
	return -1 unless $WORKSPACE;
	$this->{workspace} = $WORKSPACE;
	$this->{workspace}{nodes} = $WORKSPACE->getVars;
	$this->{workspace}{nodes} ||= {};
	$this->{workspace}{cached_nodes} = {};

	
	1;
}

##########################################################################
#
#	sub 
#		getNodeWorkspace
#
#	purpose
#		helper funciton for getNode's workspace functionality.  Given
#		a $WHERE hash ( field => value, or field => [value1, value2, value3])
#		return a list of nodes in the workspace which fullfill this query
#
#	params
#		$WHERE -- where hash, similar to getNodeWhere
#		$TYPE -- type discrimination (optional)
#
sub getNodeWorkspace {
	my ($this, $WHERE, $TYPE) = @_;
	my @results;
	$TYPE = $this->getType($TYPE) if $TYPE;

	my $cmpval = sub {
		my ($val1, $val2) = @_;

		$val1 = $val1->{node_id} if UNIVERSAL::isa( $val1, 'Everything::Node' );
		$val2 = $val2->{node_id} if UNIVERSAL::isa( $val2, 'Everything::Node' );

		$val1 eq $val2;
	};

	#we need to iterate through our workspace
	foreach my $node (keys %{ $this->{workspace}{nodes} }) {
		my $N = $this->getNode($node);
		next if $TYPE and $$N{type}{node_id} != $$TYPE{node_id};

		my $match = 1;
		foreach (keys %$WHERE) {
			if (ref $$WHERE{$_} eq 'ARRAY') {
				my $matchor = 0;
				foreach my $orval (@{ $$WHERE{$_} }) {
					$matchor = 1 if $cmpval->($$N{$_}, $orval);
				}
				$match = 0 unless $matchor;
			} else {
				$match = 0 unless $cmpval->($$N{$_}, $$WHERE{$_});
			}
		}
		push @results, $N if $match;
	}

	\@results;
}

############################################################################
#	Sub
#		rebuildNodetypeModules
#
#	Purpose
#		Call this to account for any new nodetypes that may have been
#		installed.  Primarily used by nbmasta when installing a new
#		nodeball.
#
sub rebuildNodetypeModules
{
	my ($this) = @_;
	
	$this->{nodetypeModules} = $this->buildNodetypeModules();

	return;
}


############################################################################
#	Sub
#		buildNodetypeModules
#
#	Purpose
#		Perl 5.6 throws errors if we test "can" on a non-existing
#		module.  This function builds a hashref with keys to all of
#		the modules that exist in the Everything::Node:: dir
#		This also casts "use" on the modules, loading them into memory
#
sub buildNodetypeModules
{
	my ($this) = @_;
	my %modules;	
	my $csr = $this->sqlSelectMany('title', "node", "type_nodetype=1");
	while ($_ = $csr->fetchrow_hashref) {
		my $found = 0;
		my $name = $$_{title};
		$name =~ s/\W//g;
		my $inc_name = "Everything/Node/$name.pm";
		my $modname = "Everything::Node::$name";
		foreach my $lib (@INC) {
			if (-e "$lib/$inc_name") {
				$found = 1;
				last;
			}
		}
		if ($found) {
			eval "use $modname"; 
			$modules{$modname} = 1 unless $@;
			warn "using $modname gave errors: $@" if $@;
		}
	}
	\%modules;
}

#############################################################################
#	Sub
#		resetNodeCache
#
#	Purpose
#		The node cache holds onto nodes after they have been loaded from
#		the database.  When a node is requested, it checks to see if it
#		has the node in its cache.  If it does, the cache will see if the
#		version of the node is the same as what is in the database.  This
#		version check is done *once* to save hits to the database.  If you
#		want the cache to recheck the versions, call this function.
#
sub resetNodeCache
{
	my ($this) = @_;

	$this->{cache}->resetCache();
}


#############################################################################
#	Sub
#		getDatabaseHandle
#
#	Purpose
#		This returns the DBI connection to the database.  This can be used
#		to do raw database queries.  Unless you are doing something very
#		specific, you shouldn't need to access this.
#
#	Returns
#		The DBI database connection for this NodeBase.
#
sub getDatabaseHandle
{
	my ($this) = @_;

	return $this->{dbh};
}


#############################################################################
#	Sub
#		getCache
#
#	Purpose
#		This returns the NodeCache object that we are using to cache
#		nodes.  In general, you should never need to access the cache
#		directly.  This is more for maintenance type stuff (you want to
#		check the cache size, etc).
#
#	Returns
#		A reference to the NodeCache object
#
sub getCache
{
	my ($this) = @_;

	return $this->{cache};
}


#############################################################################
#	Sub
#		sqlDelete
#
#	Purpose
#		Quickie wrapper for deleting a row or rows from a specified table.
#
#	Parameters
#		table - the sql table to delete the row from
#		where - what the sql query should match when deleting.
#		bound - an array reference of bound variables
#
#	Returns
#		0 (false) if the sql command fails, 1 (true) if successful.
#
sub sqlDelete
{
	my ($this, $table, $where, $bound) = @_;
	$bound ||= [];

	return unless $where;

	my $sql = "DELETE FROM ". $this->genTableName($table) . " WHERE $where";
	my $sth = $this->{dbh}->prepare( $sql );
	return $sth->execute( @$bound );
}


#############################################################################
#	Sub
#		sqlSelect
#
#	Purpose
#		Select specific fields from a single record.  If you need multiple
#		records, use sqlSelectMany.
#
#	Parameters
#		select - what columns to return from the select (ie "*")
#		table - the table to do the select on
#		where - string containing the search criteria
#		other - any other sql options thay you may want to pass
#
#	Returns
#		An arrayref of values from the specified fields in $select.  If
#		there is only one field, the return will be that value, not an
#		array.  Undef if no matches in the sql select.
#
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


#############################################################################
#	Sub
#               sqlSelectJoined
#
#       Purpose
#               A general wrapper function for a standard SQL select command
#		involving left joins.
#               This returns the DBI cursor.
#
#       Parameters
#               select - what columns to return from the select (ie "*")
#               table - the table to do the select on
#		joins - a hash consisting of the table name and the join criteria
#               where - the search criteria
#               other - any other sql options that you may want to pass
#
#       Returns
#               The sql cursor of the select.  Call fetchrow() on it to get
#               the selected rows.  undef if error.
#
sub sqlSelectJoined
{
	my ($this, $select, $table, $joins, $where, $other, @bound) = @_;

	my $sql = "SELECT $select ";
	$sql .= "FROM " . $this->genTableName($table) . " " if $table;

	while (my ($join, $column) = each %$joins) {
		$sql .= "LEFT JOIN " . $this->genTableName($join) . " ON $column ";
	}

	$sql .= "WHERE $where " if $where;
	$sql .= $other if $other;

	my $cursor = $this->{dbh}->prepare($sql) or return;

	$cursor->execute(@bound) or return;
	return $cursor;
}


#############################################################################
#	Sub
#		sqlSelectMany
#
#	Purpose
#		A general wrapper function for a standard SQL select command.
#		This returns the DBI cursor.
#
#	Parameters
#		select - what columns to return from the select (ie "*")
#		table - the table to do the select on
#		where - the search criteria
#		other - any other sql options that you may want to pass
# 		bound - any bound values for placeholders 
#
#	Returns
#		The sql cursor of the select.  Call fetchrow() on it to get
#		the selected rows.  undef if error.
#
sub sqlSelectMany
{
	my($this, $select, $table, $where, $other, $bound) = @_;

	$bound ||= [];

	my $sql = "SELECT $select ";
	$sql   .= "FROM " . $this->genTableName($table) . " " if $table;
	$sql   .= "WHERE $where " if $where;
	$sql   .= $other if $other;

	my $cursor = $this->{dbh}->prepare($sql) or return;
	
	return $cursor if $cursor->execute( @$bound );
}


#############################################################################
#	Sub
#		sqlSelectHashref
#
#	Purpose
#		Grab one row from a table and return it as a hash.  This just grabs
#		the first row from the select and returns it as a hash.  If you
#		want more than the first row, call sqlSelectMany and retrieve them
#		yourself.  This is basically a quickie for getting a single row.
#		
#	Parameters
#		select - what colums to return from the select (ie "*")
#		table - the table to do the select on
#		where - the search criteria
#		other - any other sql options thay you may wan to pass
#
#	Returns
#		A hashref to the row that matches the query.  undef if no match.
#	
sub sqlSelectHashref
{
	my $this   = shift;
	my $cursor = $this->sqlSelectMany(@_) or return;
	my $hash   = $cursor->fetchrow_hashref();

	$cursor->finish();
	return $hash;
}


#############################################################################
#	Sub
#		sqlUpdate
#
#	Purpose
#		Wrapper for sql update command.
#
#	Parameters
#		table - the sql table to udpate
#		data - a hash reference that contains the fields and their values
#			that will be changed.
#		where - the string that contains the constraints as to which rows
#			will be updated.
#
#	Returns
#		Number of rows affected (true if something happened, false if
#		nothing was changed).
#
sub sqlUpdate
{
	my($this, $table, $data, $where) = @_;

	return unless keys %$data;
	my ($names, $values, $bound) = $this->_quoteData( $data );

	my $sql = "UPDATE " . $this->genTableName($table) . " SET " .
		join(",\n", map { "$_ = " . shift @$values } @$names);

	$sql .= "\nWHERE $where\n" if $where;

	return $this->sqlExecute( $sql, $bound );
}


#############################################################################
#	Sub
#		sqlInsert
#
#	Purpose
#		Wrapper for the sql insert command.
#
#	Parameters
#		table - string name of the sql table to add the new row
#		data - a hash reference that contains the fieldname => value
#			pairs.  If the fieldname starts with a '-', the value is
#			treated as a literal value and thus not quoted/escaped.
#
#	Returns
#		true if successful, false otherwise.
#
sub sqlInsert
{
	my ($this, $table, $data) = @_;

	my ($names, $values, $bound) = $this->_quoteData( $data );
	my $sql = "INSERT INTO " . $this->genTableName($table) . " (" .
		join(', ', @$names) . ") VALUES(" . join(', ', @$values) . ")";

	return $this->sqlExecute( $sql, $bound );
}

#############################################################################
#
#	Private method
#		Quote database per existing convention:
#			- column name => value
#			- leading '-' means use placeholder (quote) value
#
sub _quoteData
{
	my ($this, $data) = @_;

	my (@names, @values, @bound);
	
	while (my ($name, $value) = each %$data)
	{
		if ($name =~ s/^-//)
		{
			push @values, $value;
		}
		else
		{
			push @values, '?';
			push @bound, $value;
		}
		push @names, $name;
	}

	return \@names, \@values, \@bound;
}

#############################################################################
#	Sub
#		sqlExecute
#
#	Purpose
#		Wrapper for the SQL execute command.
#
#	Parameters
#		sql   - the SQL to execute
#		bound - a reference to an array of bound variables to be used with
#			    placeholders
#
#	Returns
#		true (number of rows affected) if successful, false otherwise.
#		Failures are logged.
#
sub sqlExecute
{
	my ($this, $sql, $bound) = @_;
	my $sth;

	unless ($sth = $this->{dbh}->prepare( $sql ))
	{
		Everything::printLog( "SQL failed: $sql [@$bound]\n" );
		return;
	}

	$sth->execute( @$bound );
}

#############################################################################
#	TEMPORARY WRAPPER!
sub getNodeById
{
	my ($this, $node_id, $selectop) = @_;

	return $this->getNode($node_id, $selectop);
}


#############################################################################
#	Sub
#		newNode
#
#	Purpose
#		A more programatically "graceful" way than getNode() to get a node
#		that does not exist in the database.  This is primarily use when
#		creating new nodes or needing a node object that just has methods
#		that you wish to call.
#
#	Parameters
#		$type - a nodetype name, id, or Node object of the type of node
#			to create
#		$title - (optional) the title of the node
#
#	Returns
#		The new node.  Note that this node is not in the database.  If
#		you want to save it to the database, you will need to call insert()
#		on it.
#		
sub newNode
{
	my ($this, $type, $title) = @_;

	$title ||= "dummy" . int(rand(1000000));
	$type = $this->getType($type);

	return $this->getNode($title, $type, 'create force');
}


#############################################################################
#	Sub
#		getNode
#
#	Purpose
#		This is the one and only function needed to get a single node.  If
#		any function other than getNode() is used, the system will not work
#		properly.
#
#		This function has two forms.  One form is for getting a node by its
#		id, the other is for getting the node by its title and type.  Note
#		that if duplicate titles are allowed for the nodetype, this will only
#		get the first one that it finds in the database.
#
#	Parameters
#		$node - either the string title, node id, NODE object, or "where hash
#			ref".  The NODE object is just for ease of use, so you can call
#			this function without worrying if the node thingy is an ID or
#			object.  If this is a where hash ref, this simply does a
#			getNodeWhere() and returns the first match only (just a quicky way
#			of doing a getNodeWhere())
#		$ext - extra info.  If $node is a string title, this must be either
#			a hashref to a nodetype node, or a nodetype id.  If $node is an
#			id, $ext is optional and can be either 'light' or 'force'.  If
#			'light' it will retrieve only the information from the node table
#			(faster).  If 'force', it will reload the node even if it is
#			cached.
#		$ext2 - more extra info.  If this is a "title/type" query, passing
#			'create' will cause a dummy object to be created and returned if
#			a node is not found.  Using the dummy node, you can then add or
#			modify its fields and then do a $NODE->insert($USER) to insert it
#			into the database.  If you wish to create a node even if a node
#			of the same "title/type" exists, pass "create force".  A dummy
#			node has a node_id of '-1'.
#			If $node is a "where hash ref", this is the "order by" string
#			that you can pass to order the result by (you will still only
#			get one node).
#
#	Returns
#		A node object if successful.  undef otherwise.
#
sub getNode
{
	my ($this, $node, $ext, $ext2) = @_;
	return unless $node;

	# it may already be a node
	return $node if UNIVERSAL::isa( $node, 'Everything::Node' );

	my $NODE;
	my $cache = "";
	my $ref = ref $node;
	
	if($ref eq "HASH")
	{
		# This a "where" select
		my $nodeArray = $this->getNodeWhere($node, $ext, $ext2, 1);
		if (exists $this->{workspace}) {
			my $wspaceArray = $this->getNodeWorkspace($node, $ext);
			#the nodes we get back are unordered, must be merged
			#with the workspace.  Also any nodes which were in the 
			#nodearray, and the workspace, but not the wspace array
			#must be removed

			my @results;
			foreach (@$nodeArray) { 
				push @results, $_ unless exists $this->{workspace}{nodes}{$$_{node_id}} 
			}
			push @results, @$wspaceArray;
			return unless @results;
			my $orderby = $ext2;

			$orderby ||= "node_id";
			my $desc = 0;
			if ($orderby =~ s/\s+(asc|desc)//i) {
				$desc = 1 if $1 =~ /desc/i;
			}
			@results = sort {$$a{$orderby} cmp $$b{$orderby}} @results;
			@results = reverse @results if $desc;
			return shift @results;
		} else { 
			return shift @$nodeArray if @$nodeArray;
			return;
		}
	}
	elsif($node =~ /^\d+$/)
	{
		$NODE = $this->getNodeByIdNew($node, $ext);
		$cache = "nocache" if(defined $ext && $ext eq 'light');
	}
	else
	{
		$ext = $this->getType($ext);

		$ext2 ||= "";
		if($ext2 ne "create force")
		{
			$NODE = $this->getNodeByName($node, $ext);
		}

		if(($ext2 eq "create force") or
			($ext2 eq "create" && (not defined $NODE)))
		{
			# We need to create a dummy node for possible insertion!
			$NODE = {};

			$$NODE{node_id} = -1;
			$$NODE{title} = $node;
			$$NODE{type_nodetype} = $this->getId($ext);

			# Give the dummy node pemssions to inherit everything
			$$NODE{authoraccess} = "iiii";
			$$NODE{groupaccess} = "iiiii";
			$$NODE{otheraccess} = "iiiii";
			$$NODE{guestaccess} = "iiiii";
			$$NODE{group_usergroup} = -1;
			$$NODE{dynamicauthor_permission} = -1;
			$$NODE{dynamicgroup_permission} = -1;
			$$NODE{dynamicother_permission} = -1;
			$$NODE{dynamicguest_permission} = -1;

			# We do not want to cache dummy nodes
			$cache = "nocache";
		}
	}

	return unless($NODE);
	
	$NODE = new Everything::Node($NODE, $this, $cache);

	if (exists($$this{workspace}) and exists($$this{workspace}{nodes}{$$NODE{node_id}}) and $$this{workspace}{nodes}{$$NODE{node_id}}) {
		my $WS = $NODE->getWorkspaced();
		return $WS if $WS;
	}

	return $NODE;
}


#############################################################################
sub getNodeByName
{
	my ($this, $node, $TYPE) = @_;
	my $NODE;
	my $cursor;

	return unless($TYPE);

	$this->getRef($TYPE);
	
	$NODE = $this->{cache}->getCachedNodeByName($node, $$TYPE{title});
	return $NODE if(defined $NODE);

	$cursor = $this->sqlSelectMany("*", "node", "title='".$node."' AND type_nodetype=".$$TYPE{node_id});

	return unless $cursor;

	$NODE = $cursor->fetchrow_hashref();
	$cursor->finish();

	return unless $NODE;

	# OK, we have the hash from the 'node' table.  Now we need to construct
	# the rest of the node.
	$this->constructNode($NODE);

	return $NODE;
}


#############################################################################
#	Sub
#		getNodeZero
#
#	Purpose
#		The node with zero as its ID is a "dummy" node that represents the
#		root location of the system.  Think of this as the "/" (root
#		directory) on unix.  Only gods have access to this node.
#
#	Note
#		This is just a "dummy" node.  It does not exist in the database.
#
#	Returns
#		The "Zero Node"
#
sub getNodeZero
{
	my ($this) = @_;
	unless(exists $$this{nodezero})
	{
		$$this{nodezero} = $this->getNode("/", "location", "create force");

		$$this{nodezero}{node_id} = 0;

		$$this{nodezero}{guestaccess} = "-----";
		$$this{nodezero}{otheraccess} = "-----";
		$$this{nodezero}{groupaccess} = "-----";
		$$this{nodezero}{author_user} = $this->getNode("root", "user");
	}

	return $$this{nodezero};
}


#############################################################################
sub getNodeByIdNew
{
	my ($this, $node_id, $selectop) = @_;
	my $cursor;
	my $NODE;

	$selectop ||= "";

	return $this->getNodeZero() if($node_id == 0);
	return unless $node_id;

	if($selectop ne "force")
	{
		$NODE = $this->{cache}->getCachedNodeById($node_id);
	}

	if(not defined $NODE)
	{
		$cursor = $this->sqlSelectMany("*", "node", "node_id=$node_id");

		return unless $cursor;

		$NODE = $cursor->fetchrow_hashref();
		$cursor->finish();

		if($selectop ne "light")
		{
			# OK, we have the hash from the 'node' table.  Now we need to
			# construct the rest of the node.
			$this->constructNode($NODE);
		}
	}
	
	return $NODE;
}


#############################################################################
#	Sub
#		constructNode
#
#	Purpose
#		Given a hash that contains a row of data from the 'node' table,
#		get its type and "join" on the appropriate tables.  This function
#		is designed to work in conjuction with simple queries that only
#		search the node table, but then want a complete node.  (ie do a
#		search on the node table, find something, now we want the complete
#		node).
#
#	Parameters
#		$NODE - the incomplete node that should be filled out.
#
#	Returns
#		True (1) if successful, false (0) otherwise.  If success, the node
#		hash passed in will now be a complete node.
#
sub constructNode
{
	my ($this, $NODE) = @_;
	my $cursor;
	my $DATA;
	my $tables = $this->getNodetypeTables($$NODE{type_nodetype});
	my $table;
	my $firstTable;
	my $tablehash;
	
	return unless($tables && @$tables > 0);

	$firstTable = pop @$tables;

	foreach $table (@$tables)
	{
		$$tablehash{$table} = $firstTable . "_id=$table" . "_id";
	}

	$cursor = $this->sqlSelectJoined("*", $firstTable, $tablehash, $firstTable . "_id=" . $$NODE{node_id});
	
	return 0 unless(defined $cursor);

	$DATA = $cursor->fetchrow_hashref();
	$cursor->finish();

	@$NODE{keys %$DATA} = values %$DATA;
	
	# Make sure each field is at least defined to be nothing.
	foreach (keys %$NODE)
	{
		$$NODE{$_} = "" unless defined ($$NODE{$_});
	}

	return 1;
}


#############################################################################
#	Sub
#		getNodeWhere
#
#	Purpose
#		Get a list of NODE hashes.  This constructs a complete node.
#
#	Parameters
#		$WHERE - a hash reference to fieldname/value pairs on which to
#			restrict the select or a plain text WHERE string.
#		$TYPE - the nodetype to search.  If this is not given, this
#			will only search the fields on the "node" table since
#			without a nodetype we don't know what other tables to join
#			on.
#		$orderby - the field in which to order the results.
#		$limit - the maximum number of rows to return
#		$offset - (only if limit is provided) offset from the start of
#			the matched rows.  By using this an limit, you can retrieve
#			a specific range of rows.
#		$refTotalRows - if you want to know the total number of rows that
#			match the query, pass in a ref to a scalar (ie: \$totalrows)
#			and it will be set to the total rows that match the query.
#			This is really only useful when specifying a limit.
#
#	Returns
#		A reference to an array that contains nodes matching the criteria or
#		undef, if the operation fails
#
sub getNodeWhere { my $this = shift;

	my $selectNodeWhere = $this->selectNodeWhere( @_ );

	return unless defined $selectNodeWhere
		and UNIVERSAL::isa( $selectNodeWhere, 'ARRAY' );
	
	my @nodelist;

	foreach my $node (@{ $selectNodeWhere })
	{
		my $NODE = $this->getNode($node);
		push @nodelist, $NODE if $NODE;
	}

	return \@nodelist;
}


#############################################################################
#	Sub
#		selectNodeWhere
#
#	Purpose
#		Retrieves node id's that match the given query.
#
#	Parameters
#		$WHERE - a hash reference to fieldname/value pairs on which to
#			restrict the select or a plain text WHERE string.
#		$TYPE - the nodetype to search.  If this is not given, this
#			will only search the fields on the "node" table since
#			without a nodetype we don't know what other tables to join
#			on.
#		$orderby - the field in which to order the results.
#		$limit - a limit to the max number of rows returned
#		$offset - (only if limit is provided) offset from the start of
#			the matched rows.  By using this an limit, you can retrieve
#			a specific range of rows.
#		$refTotalRows - if you want to know the total number of rows that
#			match the query, pass in a ref to a scalar (ie: \$totalrows)
#			and it will be set to the total rows that match the query.
#			This is really only useful when specifying a limit.
#		$nodeTableOnly - (performance enhancement) Set to 1 (true) if the
#			search fields are only in the node table.  This prevents the
#			database from having to do table joins when they are not needed.
#
#	Returns
#		A reference to an array that contains the node ids that match.
#		Undef if no matches.
#
sub selectNodeWhere
{
	my ($this, $WHERE, $TYPE, $orderby, $limit, $offset, $refTotalRows,
		$nodeTableOnly) = @_;

	$TYPE = undef if defined $TYPE && $TYPE eq '';

	# The caller wishes to know the total number of matches.
	$$refTotalRows = $this->countNodeMatches( $WHERE, $TYPE ) if $refTotalRows;

	my $cursor = $this->getNodeCursor( 'node_id', $WHERE, $TYPE, $orderby,
		$limit, $offset, $nodeTableOnly );

	return unless $cursor and $cursor->execute();

	my @nodelist;
	while (my $node_id = $cursor->fetchrow())
	{
		push @nodelist, $node_id;
	}

	$cursor->finish();

	return unless @nodelist;
	return \@nodelist;
}


#############################################################################
#	Sub
#		getNodeCursor
#
#	Purpose
#		This returns the sql cursor for node matches.  Users of this object
#		can call this directly for specific searches, but the more general
#		functions selectNodeWhere() and getNodeWhere() should be used for
#		most cases.
#
#	Parameters
#		$select - The fields to select.  "*" for all, or provide a string
#			of comma delimited fields.
#		$WHERE - a hash reference to fieldname/value pairs on which to
#			restrict the select or a plain text WHERE string.
#		$TYPE - the nodetype to search.  If this is not given, this
#			will only search the fields on the "node" table since
#			without a nodetype we don't know what other tables to join
#			on.
#		$orderby - the field in which to order the results.
#		$limit - a limit to the max number of rows returned
#		$offset - (only if limit is provided) offset from the start of
#			the matched rows.  By using this an limit, you can retrieve
#			a specific range of rows.
#		$nodeTableOnly - (performance enhancement) Set to 1 (true) if the
#			search fields are only in the node table.  This prevents the
#			database from having to do table joins when they are not needed.
#			Note that if this is turned on you will not get "complete" nodes,
#			just the data from the "node" table.
#
#	Returns
#		The sql cursor from the "select".  undef if there was an error
#		in the search or no matches.  The caller is responsible for calling
#		finish() on the cursor.
#		
sub getNodeCursor
{
	my ($this, $select, $WHERE, $TYPE, $orderby, $limit, $offset,
		$nodeTableOnly) = @_;
	my $cursor;
	my $tablehash;

	$nodeTableOnly ||= 0;

	# Make sure we have a nodetype object
	$TYPE = $this->getType($TYPE);

	my $wherestr = $this->genWhereString($WHERE, $TYPE);

	# We need to generate an sql join command that has the potential
	# to join on multiple tables.  This way the SQL engine does the
	# search for us.

	# Now we need to join on the appropriate tables.
	if(not $nodeTableOnly && defined $TYPE)
	{
		my $tableArray = $this->getNodetypeTables($TYPE);
		my $table;
		
		if($tableArray)
		{
			foreach $table (@$tableArray)
			{
				$$tablehash{$table} = "node_id=" . $table . "_id";
			}
		}
	}

	my $extra;
	$extra .= "ORDER BY $orderby" if $orderby;
	$extra .= " " . $this->genLimitString($offset, $limit) if $limit;

	# Trap for SQL errors!
	my $warn;
	my $error;
	local $SIG{__WARN__} = sub {
		$warn .= $_[0];
	};
	eval { $cursor = $this->sqlSelectJoined($select, "node", $tablehash, $wherestr, $extra); };
	$error = $@;
	local $SIG{__WARN__} = sub { };
	
	if($error ne "" or $warn ne "")
	{
		Everything::logErrors($warn, $error, "$select\n($TYPE)");
		return;
	}

	return $cursor;
}


#############################################################################
#	Sub
#		countNodeMatches
#
#	Purpose
#		Doing a full query has some extra overhead.  If you just want
#		to know how many rows a certain query will match, call this.
#		It is much faster than doing a full query.
#
#	Paramters
#		$WHERE - a hash that contains the criteria for the search or a plain
#		WHERE text string.
#		$TYPE - the type of nodes this search is for.  If this is not
#			provided, it will only do the search on the node table.
#	
#	Returns
#		The number of matches found.
#
sub countNodeMatches
{
	my ($this, $WHERE, $TYPE) = @_;
	my $cursor  = $this->getNodeCursor( 'count(*)', $WHERE, $TYPE );
	my $matches = 0;
	
	if ($cursor && $cursor->execute())
	{
		($matches) = $cursor->fetchrow();
		$cursor->finish();
	}

	return $matches;
}


#############################################################################
#	Sub
#		getType
#
#	Purpose
#		This is just a quickie wrapper to get a nodetype by name or
#		id.  Saves extra typing.
#
#	Returns
#		A hash ref to a nodetype node.  undef if not found
#
sub getType
{
	my ($this, $idOrName) = @_;

	return unless defined $idOrName and $idOrName ne '';

	# The thing they passed in is good to go.
	return $idOrName if UNIVERSAL::isa( $idOrName, 'Everything::Node' );

	return $this->getNode($idOrName, 1) if $idOrName =~ /\D/;
	return $this->getNode($idOrName)    if $idOrName > 0;
	return;
}


#############################################################################
#	Sub
#		getAllTypes
#
#	Purpose
#		This returns an array that contains all of the nodetypes in the
#		system.  Useful for knowing what nodetypes exist.
#
#	Parameters
#		None
#
#	Returns
#		An array of TYPE hashes of all the nodetypes in the system
#
sub getAllTypes
{
	my ($this) = @_;

	my $cursor = $this->sqlSelectMany('node_id', 'node', 'type_nodetype=1');
	return unless $cursor;

	my @allTypes;

	while( my ($node_id) = $cursor->fetchrow() )
	{
		push @allTypes, $this->getNode($node_id);
	}

	$cursor->finish();

	return @allTypes;
}


#############################################################################
#   Sub
#       getFields
#
#   Purpose
#       Get the field names of a table.
#
#   Parameters
#       $table - the name of the table of which to get the field names
#
#   Returns
#       An array of field names
#
sub getFields
{
	my ($this, $table) = @_;

	return $this->getFieldsHash($table, 0);
}


#############################################################################
#   Sub
#		dropNodeTable
#
#	Purpose
#		Drop (delete) a table from the database.  Note!!! This is
#		permanent!  You will lose all data in that table.
#
#	Parameters
#		$table - the name of the table to drop.
#
#	Returns
#		1 if successful, 0 otherwise.
#
sub dropNodeTable
{
	my ($this, $table) = @_;
	
	# These are the tables that we don't want to drop.  Dropping one
	# of these could cause the entire system to break.  If you really
	# want to drop one of these, do it from the command line.
	my $nodrop = { map { $_ => 1 } qw(
		container document htmlcode htmlpage image links maintenance node
		nodegroup nodelet nodetype note rating user
	)};

	if (exists $nodrop->{$table})
	{
		Everything::logErrors( '', "Attempted to drop core table '$table'!" );
		return 0;
	}
	
	return 0 unless $this->tableExists($table);

	Everything::printLog("Dropping table '$table'");
	return $this->{dbh}->do("drop table " . $this->genTableName($table));
}


#############################################################################
#	Sub
#		quote
#
#	Purpose
#		A quick access to DBI's quote function for quoting strings so that
#		they do not affect the sql queries.
#
#	Paramters
#		$str - the string to quote
#
#	Returns
#		The quoted string
#
sub quote
{
	my ($this, $str) = @_;

	return $this->{dbh}->quote($str);
}


#############################################################################
#	Sub
#		genWhereString
#
#	Purpose
#		This code was stripped from selectNodeWhere.  This takes a WHERE
#		hash and a string for ordering and generates the appropriate where
#		string to pass along with a select-type sql command.  The code is
#		in this function so we can re-use it. Note that this function
#		takes less parameters than it used to, and doesn't add the 'WHERE'
#		to the beginning of the returned string.
#
#	Notes
# 		You will note that this is not a full-featured WHERE generator --
# 		there is no way to do "field1=foo OR field2=bar" 
# 		you can only OR on the same field and AND on different fields
# 		I haven't had to worry about it yet.  That day may come
#
#	Parameters
#		$WHERE - a reference to a hash that contains the criteria (ie
#			title => 'the node', etc) or a string 'title="thenode"' or a plain
#			text WHERE clause.  Note that it should be quoted, if necessary,
#			before passed in here.
#		$TYPE - a hash reference to the nodetype
#
#	Returns
#		A string that can be used for the sql query.
#
sub genWhereString
{
	my ($this, $WHERE, $TYPE) = @_;
	my $wherestr = "";
	my $tempstr;
	
	if(ref $WHERE eq "HASH")
	{
		foreach my $key (keys %$WHERE)
		{
			$tempstr = "";

			# if your where hash includes a hash to a node, you probably really
			# want to compare the ID of the node, not the hash reference.
			if ( UNIVERSAL::isa( $WHERE->{$key}, 'Everything::Node' ) )
			{
				$$WHERE{$key} = $this->getId($WHERE->{$key});
			}
			
			# If $key starts with a '-', it means it's a single value.
			if ($key =~ /^\-/)
			{ 
				$key =~ s/^\-//;
				$tempstr .= $key . '=' . $$WHERE{'-' . $key}; 
			}
			else
			{
				#if we have a list, we join each item with ORs
				if (ref ($$WHERE{$key}) eq "ARRAY")
				{
					my $LIST = $$WHERE{$key};
					my $orstr = "";	
					
					foreach my $item (@$LIST)
					{
						$orstr .= " or " if($orstr ne "");
						$item = $this->getId($item);
						$orstr .= $key . '=' . $this->quote($item); 
					}

					$tempstr .= "(" . $orstr . ")";
				}
				elsif(defined $$WHERE{$key})
				{
					$tempstr .= $key . '=' . $this->quote($$WHERE{$key});
				}
			}
			
			if($tempstr ne "")
			{
				#different elements are joined together with ANDS
				$wherestr .= " AND \n" if($wherestr ne "");
				$wherestr .= $tempstr;
			}
		}
	} else {
		$wherestr.= $WHERE;
		#note that there is no protection when you use a string
		#play it safe and use $dbh->quote, kids.
	}

	if(defined $TYPE)
	{
		$wherestr .= " AND" if($wherestr ne "");
		$wherestr .= " type_nodetype=" . $this->getId($TYPE);
	}

	return $wherestr;
}


#############################################################################
#	"Private" functions to this module
#############################################################################


#############################################################################
#	Sub
#		getNodetypeTables
#
#	Purpose
#		Returns an array of all the tables that a given nodetype joins on.
#		This will create the array, if it has not already created it.
#
#	Parameters
#		TYPE - The string name or integer Id of the nodetype
#		addnode - if true, add 'node' to list.  Defaults to false.
#
#	Returns
#		A reference to an array that contains the names of the tables
#		to join on.  If the nodetype does not join on any tables, the
#		array is empty.
#
sub getNodetypeTables
{
	my ($this, $TYPE, $addNode) = @_;
	my @tablelist;

	return unless $TYPE;

	# We need to short circuit on nodetype and nodemethod, otherwise we
	# get inf recursion.
	if(($TYPE eq "1") or ((ref $TYPE) && ($$TYPE{node_id} == 1)))
	{
		push @tablelist, "nodetype";
	}
	elsif(ref $TYPE && $$TYPE{title} eq "nodemethod")
	{
		push @tablelist, "nodemethod";
	}
	else
	{
		$this->getRef($TYPE);
		my $tables = $TYPE->getTableArray();
		push @tablelist, @{$tables} if($tables);
	}

	push @tablelist, 'node' if($addNode);

	return \@tablelist;
}


#############################################################################
#	Sub
#		getRef
#
#	Purpose
#		This makes sure that we have an array of node hashes, not node id's.
#
#	Parameters
#		Any number of node id's or node hashes (ie getRef( $n[0], $n[1], ...))
#
#	Returns
#		The node hash of the first element passed in.
#
sub getRef
{
	my $this = shift;
	local $_;

	for (@_)
	{
		next if UNIVERSAL::isa( $_, 'Everything::Node' );
		$_ = $this->getNode( $_ ) if defined $_;
	}

	return $_[0];
}


#############################################################################
#	Sub
#		getId
#
#	Purpose
#		Given a node object or a node id, return the id.  Just a quick
#		function to call to make sure that you have an id.
#
#	Parameters
#		node - a node object or a node id
#
#	Returns
#		The node id.  undef if not able to obtain an id.
#
sub getId
{
	my ($this, $node) = @_;

	return unless $node;
	return $node->{node_id} if UNIVERSAL::isa( $node, 'Everything::Node' );
	return $node if $node =~ /^-?\d+$/;
	return;
}


#############################################################################
#	Sub
#		hasPermission
#
#	Purpose
#		This does dynamic permission calculations using the specified
#		permissions node.  The permissions node contains code that will
#		calculate what permissions a user has.  For example, if a user
#		has certain flags on, the code may enable or disable write
#		permissions.  This is also a great way of abstracting permissions
#		and assigning them to actions.  In your code you can say
#		  if(hasPermission($USER, undef, 'allow vote', "x")
#		  {
#			 ... show voting stuff ...
#		  }
#
#		The code in 'allow vote' could be something like:
#		  return "x" if($$USER{experience} > 100)
#		  return "-";
#
#	Parameters
#		$USER - the user that we want to check for access.
#		$permission - the name of the permission node that contains the
#			code we want to run.
#		$modes - what modes are necessary
#
#	Returns
#		1 (true), if the user has the needed permissions, 0 (false)
#		otherwise
#
sub hasPermission
{
	my ($this, $USER, $permission, $modes) = @_;
	my $PERM = $this->getNode($permission, 'permission');

	return 0 unless $PERM;

	my $perms = eval $PERM->{code};

	return Everything::Security::checkPermissions($perms, $modes);
}


#############################################################################
#	DEPRECATED - use hasAccess()
sub canCreateNode
{
	my ($this, $USER, $TYPE) = @_;
	return $this->hasAccess($TYPE, $USER, "c");
}


#############################################################################
#	DEPRECATED - use hasAccess()
sub canDeleteNode
{
	my ($this, $USER, $NODE) = @_;
	return $this->hasAccess($NODE, $USER, "d");
}


#############################################################################
#	DEPRECATED - use hasAccess()
sub canUpdateNode
{
	my ($this, $USER, $NODE) = @_;
	return $this->hasAccess($NODE, $USER, "w");
}


#############################################################################
#	DEPRECATED - use hasAccess()
sub canReadNode
{ 
	my ($this, $USER, $NODE) = @_;
	return $this->hasAccess($NODE, $USER, "r");
}


#############################################################################
#	End of Package
#############################################################################

1;
