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

sub BEGIN
{
	use Exporter ();
	use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
}

my $dbases = {};
my $caches = {};


#############################################################################
#	Sub
#		new
#
#	Purpose
#		Constructor for is module
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
		if(defined $CACHE && (ref $CACHE eq "HASH"))
		{
			my $vars;

			#we have to set this, or it crashes when it calls a getRef
			$Everything::DB = $this; 
									
			$vars = Everything::getVars($CACHE);
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
#		other - any other sql options thay you may wan to pass
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

	$this->{dbh}->do($sql) or 
		(Everything::printErr("sqlInsert failed:\n $sql") and return 0);
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
#			node has a node_id of '0' (zero).
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

			$$NODE{node_id} = 0;
			$$NODE{title} = $node;
			$$NODE{type_nodetype} = $this->getId($ext);
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
		"select * from node where title=\"$node\" && " .
		"type_nodetype=" . $$TYPE{node_id});

	return undef unless($cursor);
	return undef unless($cursor->execute);

	$NODE = $cursor->fetchrow_hashref();
	$cursor->finish();

	return undef unless($NODE);

	# OK, we have the hash from the 'node' table.  Now we need to construct
	# the rest of the node.
	$this->constructNode($NODE);

	return $NODE;
}


#############################################################################
sub getNodeByIdNew
{
	my ($this, $node_id, $selectop) = @_;
	my $cursor;
	my $NODE;

	$selectop ||= "";

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
#		hash past in will now be a complete node.
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
	return 0 if(not defined $cursor);
	return 0 unless($cursor->execute());

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
#		loadGroupNodeIDs
#
#	Purpose
#		A group nodetype has zero or more nodes in its group.  This
#		will get the node ids from the group, and store them in the
#		'group' key of the node hash.
#
#	Parameters
#		$NODE - the group node to load node IDs for.  If the given
#			node is not a group node, this will do nothing.
#
sub loadGroupNodeIDs
{
	my ($this, $NODE, $hash, $recursive) = @_;
	my $groupTable;

	# If this node is a group node, add the nodes in its group to its array.
	if ($groupTable = $this->isGroup($NODE))
	{
		my $cursor;
		my $nid;

		if(not defined $$NODE{group})
		{
			$cursor = $this->sqlSelectMany('node_id', $groupTable,
				$groupTable . "_id=$$NODE{node_id}", 'ORDER BY orderby');
		
			while($nid = $cursor->fetchrow)
			{
				push @{ $$NODE{group} }, $nid;
			}
			
			$cursor->finish();
		}
	}
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
#			restrict the select.
#		$TYPE - the nodetype to search.  If this is not given, this
#			will only search the fields on the "node" table since
#			without a nodetype we don't know what other tables to join
#			on.
#		$orderby - the field in which to order the results.
#		$limit - the maximum number of rows to return
#		$offset - (only if limit is provided) offset from the start of
#			the matched rows.  This way you can retrieve only the 
#		$refTotalRows - if you want to know the total number of rows that
#			match the query, pass in a ref to a scalar (ie: \$totalrows)
#			and it will be set to the total rows that match the query.
#			This is really only useful when specifying a limit.
#
#	Returns
#		An array reference to an array that contains
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
#			restrict the select.
#		$TYPE - the nodetype to search.  If this is not given, this
#			will only search the fields on the "node" table since
#			without a nodetype we don't know what other tables to join
#			on.
#		$orderby - the field in which to order the results.
#		$nodeTableOnly - (performance enhancement) Set to 1 (true) if the
#			search fields are only in the node table.  This prevents the
#			database from having to do table joins when they are not needed.
#
#	Returns
#		A refernce to an array that contains the node ids that match.
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
#			restrict the select.
#		$TYPE - the nodetype to search.  If this is not given, this
#			will only search the fields on the "node" table since
#			without a nodetype we don't know what other tables to join
#			on.
#		$orderby - the field in which to order the results.
#		$nodeTableOnly - (performance enhancement) Set to 1 (true) if the
#			search fields are only in the node table.  This prevents the
#			database from having to do table joins when they are not needed.
#			Note that if this is turned on you will not get "complete" nodes,
#			just the data from the "node" table.
#
#	Returns
#		The sql cursor from the "select".  undef if their was an error
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
#		$WHERE - a hash that contains the criteria for the search
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
#		updateNode
#
#	Purpose
#		Update the given node in the database.
#
#	Parameters
#		$NODE - the node to update
#		$USER - the user attempting to update this node (used for
#			authorization)
#
#	Returns
#		The node id of the node updated if successful, 0 (false) otherwise.
#
sub updateNode
{
	my ($this, $NODE, $USER) = @_;
	my %VALUES;
	my $tableArray;
	my $table;
	my @fields;
	my $field;

	$this->getRef($NODE);
	return 0 unless ($this->canUpdateNode($USER, $NODE)); 

	$tableArray = $$NODE{type}{tableArray};

	# Cache this node since it has been updated.  This way the cached
	# version will be the same as the node in the db.
	$this->{cache}->cacheNode($NODE) if(defined $this->{cache});

	# The node table is assumed, so its not in the "joined" table array.
	# However, for this update, we need to add it.
	push @$tableArray, "node";

	# We extract the values from the node for each table that it joins
	# on and update each table individually.
	foreach $table (@$tableArray)
	{
		undef %VALUES; # clear the values hash.

		@fields = $this->getFields($table);
		foreach $field (@fields)
		{
			if (exists $$NODE{$field})
			{ 
				$VALUES{$field} = $$NODE{$field};
			}
		}

		# we don't want to chance mucking with the primary key
		# So, remove this from the hash
		delete $VALUES{$table . "_id"}; 

		$this->sqlUpdate($table, \%VALUES, $table . "_id=$$NODE{node_id}");
	}

	# We are done with tableArray.  Remove the "node" table that we put on
	pop @$tableArray;

	# This node has just been updated.  Do any maintenance if needed.
	$this->nodeMaintenance($NODE, 'update after');

	return $this->getId($NODE);
}


##############################################################################
#	Sub
#		replaceNode
#
#	Purpose
#		Given insertNode information, test whether or not the node is there
#		If it is, update it, otherwise insert the node as new.
#
#	Parameters
#		$title - the title of the node
#		$TYPE - the nodetype of the node we are looking for
#		$USER - the user trying to do this (used for authorization)
#		$DATA - a hashref that contains the information of the node to be
#			updated/inserted
#
#	Returns
#		The node_id of the node that was inserted or updated successfully.
#		0 (false) if the user did not have permissions to do this action.
#
sub replaceNode
{
	die "nothing should be calling this (NodeBase::replaceNode)";
	my ($this, $title, $TYPE, $USER, $DATA) = @_;

	if (my $N = $this->getNode($title, $TYPE))
	{
		if ($this->canUpdateNode($USER,$N))
		{
			@$N{keys %$DATA} = values %$DATA if $DATA;
			return $this->updateNode($N, $USER);
		}
	} 
	elsif($this->canCreateNode($USER, $TYPE))
	{ 
		return $this->insertNode($title, $TYPE, $USER, $DATA);
	}

	return 0;
}


#############################################################################
#	Sub
#		insertNode
#
#	Purpose
#		Insert a new node into the tables.
#
#	Parameters
#		title - the string title of the node
#		TYPE - the hash of the type that we want to insert
#		USER - the user trying to do this (used for authorization)
#		DATA - the fields/values of the node to set.
#
#	Returns
#		The id of the node inserted, or false if error (sql problem, node
#		already exists).
#
sub insertNode
{
	die "Nothing should be calling this (NodeBase::insertNode)!";
	my ($this, $title, $TYPE, $USER, $DATA) = @_;
	my $tableArray;
	my $table;
	my $NODE;

	$TYPE = $this->getType($TYPE) unless (ref $TYPE);

	unless ($this->canCreateNode($USER, $TYPE))
	{
		Everything::printErr(
			"$$USER{title} not allowed to create this type of node!");
		return 0;
	}

	if ($$TYPE{restrictdupes})
	{ 
		# Check to see if we already have a node of this title.
		my $DUPELIST = $this->sqlSelect("*", "node", "title=" .
			$this->quote($title) . " && type_nodetype=" . $$TYPE{node_id});

		if ($DUPELIST)
		{
			# A node of this name already exists and restrict dupes is
			# on for this nodetype.  Don't do anything
			return 0;
		}
	}

	# We are about to create a new node.  Do any maintenance for this type.
	$this->nodeMaintenance($NODE, 'create before');

	$this->sqlInsert("node", 
			{title => $title, 
			type_nodetype => $$TYPE{node_id}, 
			author_user => $this->getId($USER), 
			hits => 0,
			-createtime => 'now()'}); 

	# Get the id of the node that we just inserted.
	my $node_id = $this->sqlSelect("LAST_INSERT_ID()");

	# Now go and insert the appropriate rows in the other tables that
	# make up this nodetype;
	$tableArray = $$TYPE{tableArray};
	foreach $table (@$tableArray)
	{
		$this->sqlInsert($table, { $table . "_id" => $node_id });
	}

	$NODE = $this->getNodeById($node_id, 'force');
	
	# This node has just been created.  Do any maintenance if needed.
	# We do this here before calling updateNode below to make sure that
	# the 'created' routines are executed before any 'update' routines.
	$this->nodeMaintenance($NODE, 'create after');

	if ($DATA)
	{
		@$NODE{keys %$DATA} = values %$DATA;
		$this->updateNode($NODE, $USER); 
	}

	return $node_id;
}


#############################################################################
#	Sub
#		nukeNode
#
#	Purpose
#		Given a node, delete it and all of its associated table data.
#		If it is a group node, this will also clean out all of its
#		entries in its group table.
#
#	Parameters
#		$NODE - the node in which we wish to delete
#		$USER - the user trying to do this (used for authorization)
#
#	Returns
#		True if successful, false otherwise.
#	
sub nukeNode
{
	my ($this, $NODE, $USER) = @_;
	my $tableArray;
	my $table;
	my $result = 0;
	my $groupTable;
	
	$this->getRef($NODE, $USER);
	
	return 0 unless ($this->canDeleteNode($USER, $NODE));

	# This node is about to be deleted.  Do any maintenance if needed.
	$this->nodeMaintenance($NODE, 'delete before');
	
	# Delete this node from the cache that we keep.
	$this->{cache}->removeNode($NODE);

	$tableArray = $$NODE{type}{tableArray};

	push @$tableArray, "node";  # the node table is not in there.

	foreach $table (@$tableArray)
	{
		$result += $this->{dbh}->do("DELETE FROM $table WHERE " . $table . 
			"_id=$$NODE{node_id}");
	}

	pop @$tableArray; # remove the implied "node" that we put on
	
	# Remove all links that go from or to this node that we are deleting
	$this->{dbh}->do("DELETE FROM links 
		WHERE to_node=$$NODE{node_id} 
		OR from_node=$$NODE{node_id}");

	# If this node is a group node, we will remove all of its members
	# from the group table.
	if($groupTable = $this->isGroup($NODE))
	{
		# Remove all group entries for this group node
		$this->{dbh}->do("DELETE FROM $groupTable WHERE " . $groupTable . 
			"_id=$$NODE{node_id}");
	}
	
	$this->nodeMaintenance($NODE, 'delete after');

	# This will be zero if nothing was deleted from the tables.
	return $result;
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

	@fields;
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
#		dropNodeTable
#
#	Purpose
#		Drop (delete) a table from a the database.  Note!!! This is
#		perminent!  You will lose all data in that table.
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
#		WHERE - a reference to a hash that contains the criteria (ie
#			title => 'the node', etc).
#		TYPE - a hash reference to the nodetype
#		orderby - a string that contains information on how the sql
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
	
	if($WHERE)
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
			
			# If $key starts with a '-', it means its a single value.
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
				elsif($$WHERE{$key})
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
#		typeNameOrId - The string name or integer Id of the nodetype
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

	# We need to short curcuit on nodetype and nodemethod, otherwise we
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
			$_[$i] = $this->getNode($_[$i]) if($_[$i]);
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
#	Returns
#		The node id.  undef if not able to obtain an id.
#
sub getId
{
	my ($this, $node) = @_;

	if(ref $node)
	{
		return $$node{node_id};
	}
	elsif($node =~ /^\d+$/)
	{
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
#	DEPRICATED - use hasAccess()
sub canCreateNode
{
	my ($this, $USER, $TYPE) = @_;
	return $this->hasAccess($TYPE, $USER, "c");
}


#############################################################################
#	DEPRICATED - use hasAccess()
sub canDeleteNode
{
	my ($this, $USER, $NODE) = @_;
	return $this->hasAccess($NODE, $USER, "d");
}


#############################################################################
#	DEPRICATED - use hasAccess()
sub canUpdateNode
{
	my ($this, $USER, $NODE) = @_;
	return $this->hasAccess($NODE, $USER, "w");
}


#############################################################################
#	DEPRICATED - use hasAccess()
sub canReadNode
{ 
	my ($this, $USER, $NODE) = @_;
	return $this->hasAccess($NODE, $USER, "r");
}


#############################################################################
#	End of Package
#############################################################################

1;
