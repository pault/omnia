package Everything::NodeBase;

#############################################################################
#	Everything::NodeBase
#		Wrapper for the Everything database and cache.  
#
#	Copyright 1999 Everything Development Inc.
#	Format: tabs = 4 spaces
#
#############################################################################

use strict;
use DBI;
use Everything;
use Everything::NodeCache;
use Everything::Node;

my $dbases = {};
my $caches = {};


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
#			permissions dynmically or not manually changing them often) set
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
	my ($className, $dbname, $staticNodetypes) = @_;
	my $this = {};
	my $setCacheSize = 0;
	
	bless $this;
	$staticNodetypes ||= 0;

	# If we have not created a connection to the database for the
	# one given, do so.
	if(not exists $dbases->{$dbname})
	{
		my $db = {};
		
		# A connection to this database does not exist.  Create one.
		# NOTE!  This has no database password protection!!!
		$db->{dbh} = DBI->connect("DBI:mysql:$dbname", "root", "");
		$this->{dbh} = $db->{dbh};
		
		die "Unable to get database connection!" unless($db->{dbh});

		$db->{cache} = new Everything::NodeCache($this, 300);
		$dbases->{$dbname} = $db;
		
		$setCacheSize = 1;
	}

	$this->{dbh} = $dbases->{$dbname}->{dbh};
	$this->{cache} = $dbases->{$dbname}->{cache};
	$this->{dbname} = $dbname;
	$this->{staticNodetypes} = $staticNodetypes;

	if($setCacheSize && $this->getType("setting"))
	{
		my $CACHE = $this->getNode("cache settings", "setting");
		my $cacheSize = 300;

		# Get the settings from the system
		if(defined $CACHE && (ref $CACHE eq "Everything::Node"))
		{
			my $vars;

			#we have to set this, or it crashes when it calls a getRef
			$Everything::DB = $this; 
									
			$vars = $CACHE->getVars();
			$cacheSize = $$vars{maxSize} if(exists $$vars{maxSize});
		}

		$this->{cache}->setCacheSize($cacheSize);
	}

	$this->{cache}->clearSessionCache;
	return $this;
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
#
#	Returns
#		0 (false) if the sql command fails, 1 (true) if successful.
#
sub sqlDelete
{
	my ($this, $table, $where) = @_;

	$where or return;

	my $sql = "DELETE FROM $table WHERE $where";

	return 1 if($this->{dbh}->do($sql));

	return 0;
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
#		select - what colums to return from the select (ie "*")
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
	my($this, $select, $table, $where, $other) = @_;
	my $cursor = $this->sqlSelectMany($select, $table, $where, $other);
	my @result;
	
	return undef if(not defined $cursor);

	@result = $cursor->fetchrow();
	$cursor->finish();
	
	return $result[0] if(scalar @result == 1);
	return undef if(scalar @result == 0);
	return \@result;
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
#		select - what colums to return from the select (ie "*")
#		table - the table to do the select on
#		where - the search criteria
#		other - any other sql options thay you may wan to pass
#
#	Returns
#		The sql cursor of the select.  Call fetchrow() on it to get
#		the selected rows.  undef if error.
#
sub sqlSelectMany
{
	my($this, $select, $table, $where, $other) = @_;

	my $sql="SELECT $select ";
	$sql .= "FROM $table " if $table;
	$sql .= "WHERE $where " if $where;
	$sql .= "$other" if $other;

	my $cursor = $this->{dbh}->prepare($sql);
	
	return $cursor if($cursor->execute());
	return undef;
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
	my ($this, $select, $table, $where, $other) = @_;
	my $cursor = $this->sqlSelectMany($select, $table, $where, $other);
	my $hash;
	
	if(defined $cursor)
	{
		$hash = $cursor->fetchrow_hashref();
		$cursor->finish();
	}

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
	my $sql = "UPDATE $table SET";

	return unless keys %$data;

	foreach (keys %$data)
	{
		if (/^-/)
		{
			# If the parameter name starts with a '-', we need to treat
			# the value as a literal value (don't quote it).
			s/^-//; 
			$sql .="\n  $_ = " . $$data{'-'.$_} . ",";
		}
		else
		{
			# We need to quote the value
			$sql .="\n  $_ = " . $this->{dbh}->quote($$data{$_}) . ",";
		}
	}

	chop($sql);

	$sql .= "\nWHERE $where\n" if $where;

	 return ($this->{dbh}->do($sql));
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
	my ($names, $values);

	foreach (keys %$data)
	{
		if (/^-/)
		{
			$values.="\n  ".$$data{$_}.","; s/^-//;
		}
		else
		{
			$values.="\n  " . $this->{dbh}->quote($$data{$_}) . ",";
		}
		
		$names .= "$_,";
	}

	chop($names);
	chop($values);

	my $sql = "INSERT INTO $table ($names) VALUES($values)\n";

	my $result = $this->{dbh}->do($sql);

	Everything::printLog("sqlInsert failed:\n $sql") unless($result);

	return $result;
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
	my $NODE;
	my $cache = "";
	my $ref = ref $node;
	
	if($ref =~ /Everything::Node/)
	{
		# This thing is already a node!
		return $node;
	}
	elsif($ref eq "HASH")
	{
		# This a "where" select
		my $nodeArray = $this->getNodeWhere($node, $ext, $ext2);
		return (shift @$nodeArray) if(@$nodeArray > 0);
		return undef;
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

	return undef unless($NODE);
	
	$NODE = new Everything::Node($NODE, $this, $cache);

	return $NODE;
}


#############################################################################
sub getNodeByName
{
	my ($this, $node, $TYPE) = @_;
	my $NODE;
	my $cursor;

	return undef unless($TYPE);

	$this->getRef($TYPE);
	
	$NODE = $this->{cache}->getCachedNodeByName($node, $$TYPE{title});
	return $NODE if(defined $NODE);

	$cursor = $this->getDatabaseHandle()->prepare(
		"select * from node where title=? && " .
		"type_nodetype=" . $$TYPE{node_id});

	return undef unless($cursor);
	return undef unless($cursor->execute($node));

	$NODE = $cursor->fetchrow_hashref();
	$cursor->finish();

	return undef unless($NODE);

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
	return undef unless($node_id);

	if($selectop ne "force")
	{
		$NODE = $this->{cache}->getCachedNodeById($node_id);
	}

	if(not defined $NODE)
	{
		$cursor = $this->getDatabaseHandle()->prepare(
			"select * from node where node_id=$node_id;");

		return undef unless($cursor);
		return undef unless($cursor->execute);

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
	my $sql;
	my $firstTable;
	
	return unless($tables && @$tables > 0);

	$firstTable = pop @$tables;
	$sql = "select * from " . $firstTable;

	foreach $table (@$tables)
	{
		$sql .= " left join $table on $firstTable" . "_id=$table" . "_id";
	}

	$sql .= " where $firstTable" . "_id=$$NODE{node_id};";
	
	$cursor = $this->getDatabaseHandle()->prepare($sql);
	return 0 unless((defined $cursor) && ($cursor->execute()));

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
#		A reference to an array that contains nodes matching the criteria
#
sub getNodeWhere
{
	my ($this, $WHERE, $TYPE, $orderby, $limit, $offset, $refTotalRows) = @_;
	my $NODE;
	my $node;
	my $nodeIdList;
	my @nodelist;

	$nodeIdList = $this->selectNodeWhere($WHERE, $TYPE, $orderby, $limit,
		$offset, $refTotalRows);

	foreach $node (@$nodeIdList)
	{
		$NODE = $this->getNode($node);
		push @nodelist, $NODE if($NODE);
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
	my $cursor;
	my $select;
	my @nodelist;
	my $node_id;

	$TYPE = undef if(defined $TYPE && $TYPE eq "");

	if($refTotalRows)
	{
		# The caller wishes to know what the total number of matches are
		# This will quickly count how many total (total being without
		# the limit) matches we have.
		$$refTotalRows = $this->countNodeMatches($WHERE, $TYPE);
	}
	
	$cursor = $this->getNodeCursor("*", $WHERE, $TYPE, $orderby, $limit,
		$offset, $nodeTableOnly);
	
	if((defined $cursor) && ($cursor->execute()))
	{
		while ((($node_id) = $cursor->fetchrow)) 
		{
			push @nodelist, $node_id;
		}
		
		$cursor->finish();
	}

	return undef unless(@nodelist);
	
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
	my $wherestr;

	$nodeTableOnly ||= 0;

	# Make sure we have a nodetype object
	$TYPE = $this->getType($TYPE);

	$wherestr = $this->genWhereString($WHERE, $TYPE, $orderby, $limit, $offset);

	# We need to generate an sql join command that has the potential
	# to join on multiple tables.  This way the SQL engine does the
	# search for us.
	$select = "SELECT $select FROM node";

	# Now we need to join on the appropriate tables.
	if(not $nodeTableOnly && defined $TYPE)
	{
		my $tableArray = $this->getNodetypeTables($TYPE);
		my $table;
		
		if($tableArray)
		{
			foreach $table (@$tableArray)
			{
				$select .= " LEFT JOIN $table ON node_id=" . $table . "_id";
			}
		}
	}

	$select .= " $wherestr" if($wherestr);
	$cursor = $this->{dbh}->prepare($select);

	return $cursor if($cursor->execute());
	return undef;
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
	my $csr = $this->getNodeCursor("count(*)", $WHERE, $TYPE);
	my $matches = 0;
	
	if($csr && $csr->execute())
	{
		($matches) = $csr->fetchrow();
		$csr->finish();
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
	
	my $ref = ref $idOrName;
	if($ref =~ /Everything::Node/)
	{
		# The thing they passed in is good to go.
		return $idOrName;
	}
	
	return undef if((not defined $idOrName) || ($idOrName eq ""));

	my $NODE;

	if($idOrName =~ /\D/) # Does it contain non-digits?
	{
		# Note that we assume that 'nodetype' is id 1.  If this changes,
		# this will break.
		$NODE = $this->getNode($idOrName, 1);
	}
	elsif($idOrName > 0)
	{
		$NODE = $this->getNode($idOrName);
	}

	return $NODE;
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
	my $sql;
	my $cursor;
	my @allTypes = ();
	my $node_id;
	my $TYPE = $this->getType("nodetype");
	
	$sql = "select node_id from node where type_nodetype=" . $$TYPE{node_id};
	$cursor = $this->{dbh}->prepare($sql);
	if($cursor && $cursor->execute())
	{
		while( ($node_id) = $cursor->fetchrow() )
		{
			$TYPE = $this->getType($node_id);
			push @allTypes, $TYPE;
		}
		
		$cursor->finish();
	}

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

	my $cursor = $this->{dbh}->prepare_cached("show columns from $table");

	$cursor->execute;
	while ($field = $cursor->fetchrow_hashref)
	{
		$value = ( ($getHash == 1) ? $field : $$field{Field});
		push @fields, $value;
	}

	$cursor->finish();

	return @fields;
}


#############################################################################
#	Sub
#		tableExists
#
#	Purpose
#		Check to see if a table of the given name exists in this database.
#
#	Parameters
#		$tableName - the table to check for.
#
#	Returns
#		1 if it exists, 0 if not.
#
sub tableExists
{
	my ($this, $tableName) = @_;
	my $cursor = $this->{dbh}->prepare("show tables");
	my $table;
	my $exists = 0;

	$cursor->execute();
	while((($table) = $cursor->fetchrow()) && (not $exists))
	{
		  $exists = 1 if($table eq $tableName);
	}

	$cursor->finish();

	return $exists;
}


#############################################################################
#	Sub
#		createNodeTable
#
#	Purpose
#		Create a new database table for a node, if it does not already
#		exist.  This creates a new table with one field for the id of
#		the node in the form of tablename_id.
#
#	Parameters
#		$tableName - the name of the table to create
#
#	Returns
#		1 if successful, 0 if failure, -1 if it already exists.
#
sub createNodeTable
{
	my ($this, $table) = @_;
	my $tableid = $table . "_id";
	my $result;
	
	return -1 if($this->tableExists($table));

	$result = $this->{dbh}->do("create table $table ($tableid int(11)" .
		" DEFAULT '0' NOT NULL, PRIMARY KEY($tableid))");

	return $result;
}


#############################################################################
#	Sub
#		createGroupTable
#
#	Purpose
#		Creates a new group table if it does not already exist.
#
#	Returns
#		1 if successful, 0 if failure, -1 if it already exists.
#		
sub createGroupTable
{
	my ($this, $table) = @_;

	return -1 if($this->tableExists($table));
		
	my $dbh = $this->getDatabaseHandle();
	my $tableid = $table . "_id";

	my $sql;
	
	$sql = <<SQLEND;
		create table $table (
			$tableid int(11) DEFAULT '0' NOT NULL auto_increment,
			rank int(11) DEFAULT '0' NOT NULL,
			node_id int(11) DEFAULT '0' NOT NULL,
			orderby int(11) DEFAULT '0' NOT NULL,
			PRIMARY KEY(" . $table . "_id,rank)
		);
SQLEND

	return $dbh->do($sql);
}

#############################################################################
#	Sub
#		dropNodeTable
#
#	Purpose
#		Drop (delete) a table from a the database.  Note!!! This is
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
	# of these, could cause the entire system to break.  If you really
	# want to drop one of these, do it from the command line.
	my $nodrop = {
		"container" => 1,
		"document" => 1,
		"htmlcode" => 1,
		"htmlpage" => 1,
		"image" => 1,
		"links" => 1,
		"maintenance" => 1,
		"node" => 1,
		"nodegroup" => 1,
		"nodelet" => 1,
		"nodetype" => 1,
		"note" => 1,
		"rating" => 1,
		"user" => 1 };

	if(exists $$nodrop{$table})
	{
		Everything::printLog("WARNING! Attempted to drop core table $table!");
		return 0;
	}
	
	return 0 unless($this->tableExists($table));

	Everything::printLog("Dropping table $table");
	return $this->{dbh}->do("drop table $table");
}


#############################################################################
#	Sub
#		addFieldToTable
#
#	Purpose
#		Add a new field to an existing database table.
#
#	Parameters
#		$table - the table to add the new field to.
#		$fieldname - the name of the field to add
#		$type - the type of the field (ie int(11), char(32), etc)
#		$primary - (optional) is this field a primary key?  Defaults to no.
#		$default - (optional) the default value of the field.
#
#	Returns
#		1 if successful, 0 if failure.
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
	
	$sql = "alter table $table add $fieldname $type";
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

		$this->{dbh}->do("alter table $table drop primary key") if(@prikeys > 0);

		push @prikeys, $fieldname; # add the new field to the primaries
		$primaries = join ',', @prikeys;
		$this->{dbh}->do("alter table $table add primary key($primaries)");
	}

	return 1;
}


#############################################################################
#	Sub
#		dropFieldFromTable
#
#	Purpose
#		Remove a field from the given table.
#
#	Parameters
#		$table - the table to remove the field from
#		$field - the field to drop
#
#	Returns
#		1 if successful, 0 if failure
#
sub dropFieldFromTable
{
	my ($this, $table, $field) = @_;
	my $sql;

	$sql = "alter table $table drop $field";

	return $this->{dbh}->do($sql);
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

	return ($this->{dbh}->quote($str));
}


#############################################################################
#	Sub
#		genWhereString
#
#	Purpose
#		This code was stripped from selectNodeWhere.  This takes a WHERE
#		hash and a string for ordering and generates the appropriate where
#		string to pass along with a select-type sql command.  The code is
#		in this function so we can re-use it.
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
#		$orderby - a string that contains information on how to order results
#		$limit - a limit to the max number of rows returned
#		$offset - (only if limit is provided) offset from the start of
#			the matched rows.  By using this an limit, you can retrieve
#			a specific range of rows.
#			query should order the result if more than one match is found.
#
#	Returns
#		A string that can be used for the sql query.
#
sub genWhereString
{
	my ($this, $WHERE, $TYPE, $orderby, $limit, $offset) = @_;
	my $wherestr = "";
	my $tempstr;
	
	if(ref $WHERE eq "HASH")
	{
		foreach my $key (keys %$WHERE)
		{
			$tempstr = "";

			# if your where hash includes a hash to a node, you probably really
			# want to compare the ID of the node, not the hash reference.
			if (ref ($$WHERE{$key}) eq "HASH")
			{
				$$WHERE{$key} = $this->getId($$WHERE{$key});
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
				$wherestr .= " && \n" if($wherestr ne "");
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
		$wherestr .= " &&" if($wherestr ne "");
		$wherestr .= " type_nodetype=" . $this->getId($TYPE);
	}

	# Prepend with "WHERE".  If we have made it here and wherestr is empty,
	# there are no restrictions on the search.
	$wherestr = "WHERE $wherestr" if($wherestr && $wherestr ne "");

	$wherestr .= " ORDER BY $orderby" if $orderby;

	if($limit)
	{
		$offset ||= 0;
		$wherestr .= " LIMIT $offset,$limit";
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

	return undef unless($TYPE);

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
	my $this = shift @_;
	
	for (my $i = 0; $i < @_; $i++)
	{ 
		unless (ref ($_[$i]))
		{
			$_[$i] = $this->getNode($_[$i]) if(defined $_[$i]);
		}
	}
	
	ref $_[0];
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

	return undef unless $node;
	if(ref $node)
	{
		return $$node{node_id};
	}
	elsif($node =~ /^-?\d+$/)
	{
		# If it is a number, just return it.
		return $node;
	}

	return undef;
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
	my $perms;

	return 0 unless($PERM);

	$perms = eval($$PERM{code});

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
