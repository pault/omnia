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
#		where - the search criteria
#		other - any other sql options thay you may wan to pass
#
#	Returns
#		An array of values from the specified fields in $select.  If
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
	return @result;
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

	$this->{dbh}->do($sql) or 
		(Everything::printErr("sqlUpdate failed:\n $sql\n") and return 0);
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
#	Sub
#		getNode
#
#	Purpose
#		Get a node by title and type.  This only returns the first match. 
#		To get all matches, use	getNodeWhere which returns an array.
#
#	Parameters
#		$title - the title or numeric ID of the node
#		$TYPE - the nodetype hash of the node, or the title of the type.
#
#	Returns
#		A node hashref if a node is found.  undef otherwise.
#
sub getNode
{
	my ($this, $title, $TYPE) = @_;
	my $NODE;

	if (not $TYPE and $title =~ /^\d+$/) {
		return $this->getNodeById($title);
	}
	
	if(defined $TYPE)
	{
		$TYPE = $this->getType($TYPE) unless(ref $TYPE eq "HASH");
	}

	$NODE = $this->{cache}->getCachedNodeByName($title, $$TYPE{title});
	return $NODE if(defined $NODE);
	
	($NODE) = $this->getNodeWhere({ "title" => $title }, $TYPE);

	if(defined $NODE)
	{
		$this->{cache}->cacheNode($NODE);
	}

	return $NODE;
}


#############################################################################
#	Sub
#		getNodeById
#
#	Purpose
#		This takes a node id or node hash reference (all we need is the id)
#		and loads the node into a hash by attaching the other table data.
#
#		If the node is a group node, the group members will be added to
#		the "group" key in the hash.
#
#	Parameters
#		N - either an integer node Id, or a reference to a node hash.
#		selectop - either "force", "light", or "".  If set to "force", this
#			will do the work even if the node is cached.  If set to "light"
#			it just attaches the nodetype hash to the node.  If "" or null,
#			it resolves nodegroup stuff and attaches the extra table data.
#
#	Returns
#		A node hash reference.  False if failure.
#
sub getNodeById
{
	my ($this, $N, $selectop) = @_;
	my $groupTable;
	my $NODETYPE;
	my $NODE;
	my $table;
	my $cachedNode;

	$selectop ||= '';
    return -1 if $N == -1;
	$N = $this->getId($N);
	return undef unless $N;
	
	# See if we have this node cached already
	$cachedNode = $this->{cache}->getCachedNodeById($N);
	return $cachedNode unless ($selectop eq 'force' or not $cachedNode);
	
	$NODE = $this->sqlSelectHashref('*', 'node', "node_id=$N");
	return undef if(not defined $NODE);
	
	$NODETYPE = $this->getType($$NODE{type_nodetype});
	return undef if(not defined $NODETYPE);

	# Wire up the node's nodetype
	$$NODE{type} = $NODETYPE;

	if ($selectop eq 'light')
	{
		# Note that we do not cache the node.  We don't want to cache a
		# node that does not have its table data (its not complete).
		return $NODE;
	}

	# Get the rest of the info for this node
	$this->constructNode($NODE);

	# Fill out the group in the node, if its a group node.
	$this->loadGroupNodeIDs($NODE);

	# Store this node in the cache.
	$this->{cache}->cacheNode($NODE);

	return $NODE;
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
#
#	Returns
#		An array of integer node id's that match the query.
#
sub getNodeWhere
{
	my ($this, $WHERE, $TYPE, $orderby) = @_;
	my $NODE;
	my @nodelist;
	my $cursor;

	$cursor = $this->getNodeCursor($WHERE, $TYPE, $orderby);
	
	if(defined $cursor)
	{
		while($NODE = $cursor->fetchrow_hashref)
		{
			# NOTE: This duplicates some stuff from getNodeById().  The
			# reason that we don't call getNodeById here is pure
			# performance.  We already have the entire hash.  We just
			# need the type and any group info.  Calling getNodeById
			# would result in two extra sql queries that we don't need.
			
			# Attach the type to the node
			$$NODE{type} = $this->getType($$NODE{type_nodetype});

			# Fill out the group, if its a group node.
			$this->loadGroupNodeIDs($NODE);
			
			push @nodelist, $NODE;
		}

		$cursor->finish();
	}

	return @nodelist;
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
#			Note that if this is turned on you will not get "complete" nodes,
#			just the data from the "node" table.
#
#	Returns
#		A refernce to an array that contains the node ids that match.
#		Undef if no matches.
#
sub selectNodeWhere
{
	my ($this, $WHERE, $TYPE, $orderby, $nodeTableOnly) = @_;
	my $cursor;
	my $select;
	my @nodelist;
	my $node_id;
	
	$cursor = $this->getNodeCursor($WHERE, $TYPE, $orderby, $nodeTableOnly);
	
	if((defined $cursor) && ($cursor->execute()))
	{
		while (($node_id) = $cursor->fetchrow) 
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
	my ($this, $WHERE, $TYPE, $orderby, $nodeTableOnly) = @_;
	my $cursor;
	my $select;

	$nodeTableOnly ||= 0;

	$TYPE = $this->getType($TYPE) if((defined $TYPE) && (ref $TYPE ne "HASH"));

	my $wherestr = $this->genWhereString($WHERE, $TYPE, $orderby);

	# We need to generate an sql join command that has the potential
	# to join on multiple tables.  This way the SQL engine does the
	# search for us.
	$select = "SELECT * FROM node";

	# Now we need to join on the appropriate tables.
	if((! $nodeTableOnly) && (defined $TYPE) && (ref $$TYPE{tableArray}))
	{
		my $tableArray = $$TYPE{tableArray};
		my $table;
		
		foreach $table (@$tableArray)
		{
			$select .= " LEFT JOIN $table ON node_id=" . $table . "_id";
		}
	}

	$select .= " WHERE " . $wherestr if($wherestr);
	$cursor = $this->{dbh}->prepare($select);

	return $cursor if($cursor->execute());
	return undef;
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
	my $TYPE = $this->getType($$NODE{type_nodetype});
	my $cursor;
	my $DATA;
	
	return 0 unless((defined $TYPE) && (ref $$TYPE{tableArray}));

	$cursor = $this->getNodeCursor({node_id => $$NODE{node_id}}, $TYPE);

	return 0 if(not defined $cursor);

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

	# This node is about to be updated.  Do any maintenance if needed.
	$this->nodeMaintenance($NODE, 'update before');
	
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
	my ($node_id) = $this->sqlSelect("LAST_INSERT_ID()");

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
#		Get a nodetype.  This must be called to get a nodetype.  You
#		cannot retrieve a nodetype through selectNodeWhere, getNodeById,
#		etc.  Nodetypes are derived and inherit values from "parent"
#		nodetypes.  This takes care of the tricky part of getting the
#		nodetypes loaded and properly derives their values.
#
#	Returns
#		A hash ref to a nodetype node.  undef if not found
#
sub getType
{
	my ($this, $idOrName) = @_;
	my $TYPE;
	my $NODE;
	my $field;
	my $fromCache = 1;

	# We assume that the nodetypes join on the 'nodetype' table and the
	# nodetype 'nodetype' is always id #1.  If this changes, this will
	# break and we will need to change this stuff.

	# If they pass in a hash, just take the id.
	$idOrName = $$idOrName{node_id} if(ref $idOrName eq "HASH");
	
	return undef if((not defined $idOrName) || ($idOrName eq ""));

	if($idOrName =~ /\D/) # Does it contain non-digits?
	{
		# It is a string name of the nodetype we are looking for.
		$TYPE = $this->{cache}->getCachedNodeByName($idOrName, "nodetype");

		if(not defined $TYPE)
		{
			$TYPE = $this->sqlSelectHashref("*",
				"node left join nodetype on node_id=nodetype_id",
				"title=" . $this->quote($idOrName) . " && type_nodetype=1");
			
			$fromCache = 0;
		}
	}
	elsif($idOrName > 0)
	{
		# Its an id
		$TYPE = $this->{cache}->getCachedNodeById($idOrName);

		if(not defined $TYPE)
		{
			$TYPE = $this->sqlSelectHashref("*",
				"node left join nodetype on node_id=nodetype_id",
				"node_id=$idOrName && type_nodetype=1");
			
			$fromCache = 0;
		}
	}
	else
	{
		# We only get here if the id is zero or negative
		return undef;
	}

	# If we did not find a matching nodetype, forget it.
	return undef unless(defined $TYPE);

	if(not exists $$TYPE{type})
	{
		# We need to assign the "type".
		if($$TYPE{node_id} == 1)
		{
			# This is the nodetype nodetype, it is its own type.
			$$TYPE{type} = $TYPE;
		}
		else
		{
			# Get the type and assign it.
			$$TYPE{type} = $this->getType($$TYPE{type_nodetype});
		}
	}
	
	if(not exists $$TYPE{resolvedInheritance})
	{
		# If this didn't come from the cache, we need to cache it
		$this->{cache}->cacheNode($TYPE, 1) if((not $fromCache) && 
			(not $this->{staticNodetypes}));
		
		$TYPE = $this->deriveType($TYPE);

		# If we have static nodetypes, we can do a performance enhancement
		# by caching the completed nodes.
		if($this->{staticNodetypes})
		{
			$this->{cache}->cacheNode($TYPE, 1);
		}
	}

	return $TYPE;
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
	my ($this, $WHERE, $TYPE, $orderby) = @_;
	my $wherestr = "";
	my $tempstr;
	
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

	if(defined $TYPE)
	{
		$wherestr .= " &&" if($wherestr ne "");
		$wherestr .= " type_nodetype=$$TYPE{node_id}";
	}

	$wherestr .= " ORDER BY $orderby" if $orderby;
	
	return $wherestr;
}


#############################################################################
#	"Private" functions to this module
#############################################################################


#############################################################################
sub deriveType
{
	my ($this, $TYPE) = @_;
	my $PARENT;
	my $NODETYPE;
	my $field;
	
	# If this type has been derived already, don't do it again.
	return $TYPE if(exists $$TYPE{resolvedInheritance});

	# Make a copy of the TYPE.  We don't want to change whatever is stored
	# in the cache if static nodetypes are turned off.
	foreach $field (keys %$TYPE)
	{
		$$NODETYPE{$field} = $$TYPE{$field};
	}

	$$NODETYPE{sqltablelist} = $$NODETYPE{sqltable};
	$PARENT = $this->getType($$NODETYPE{extends_nodetype});

	if(defined $PARENT)
	{
		foreach $field (keys %$PARENT)
		{
			# We add some fields that are not apart of the actual
			# node, skip these because they are never inherited
			# anyway. (if more custom fields are added, add them
			# here.  We don't want to inherit them.)
			my %skipfields = (
				"tableArray" => 1,
				"resolvedInheritance" => 1 );
			
			next if(exists $skipfields{$field});
			
			# If a field in a nodetype is '-1', this field is derived from
			# its parent.
			if($$NODETYPE{$field} eq "-1")
			{
				$$NODETYPE{$field} = $$PARENT{$field};
			}
			elsif($field =~ /default.*access/)
			{
				$$NODETYPE{$field} = $this->inheritPermissions(
					$$NODETYPE{$field}, $$PARENT{$field});
			}
			elsif(($field eq "sqltablelist") && ($$PARENT{$field} ne ""))
			{
				# Inherited sqltables are added onto the list.  Derived
				# nodetypes "extend" parent nodetypes.
				$$NODETYPE{$field} .= "," if($$NODETYPE{$field} ne "");
				$$NODETYPE{$field} .= "$$PARENT{$field}";
			}
			elsif(($field eq "grouptable") && ($$PARENT{$field} ne "") &&
				($$NODETYPE{$field} eq ""))
			{
				# We are inheriting from a group nodetype and we have not
				# specified a grouptable, so we will use the same table
				# as our parent nodetype.
				$$NODETYPE{$field} = $$PARENT{$field};
			}
		}
	}

	$this->getNodetypeTables($NODETYPE);

	# If this is the 'nodetype' nodetype, we need to reassign the 'type'
	# field to point to this completed nodetype.
	if($$NODETYPE{title} eq "nodetype")
	{
		$$NODETYPE{type} = $NODETYPE;
	}
	
	# Flag this nodetype as complete.  We use this for checking to make
	# sure that it is a valid nodetype.  This should be the only place
	# that this flag gets set!
	$$NODETYPE{resolvedInheritance} = 1;

	return $NODETYPE;
}


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
	my ($this, $TYPE) = @_;
	$TYPE = $this->getType($TYPE) unless ref $TYPE;
	my $tables;
	my @tablelist;
	my @nodupes;
	my $warn = "";

	if(defined $$TYPE{tableArray})
	{
		# We already calculated this, return it.
		return $$TYPE{tableArray};
	}

	$tables = $$TYPE{sqltablelist};

	if((defined $tables) && ($tables ne ""))
	{
		my %tablehash;
		
		# remove all spaces (table names should not have spaces in them)
		$tables =~ s/ //g;

		# Remove any crap that the user may put in there (stray commas, etc). 
		$tables =~ s/,{2,}/,/g;
		$tables =~ s/^,//;
		$tables =~ s/,$//;
		
		@tablelist = split ",", $tables;

		# Make sure there are no dupes!
		foreach (@tablelist)
		{
			if(defined $tablehash{$_})
			{
				$tablehash{$_} = $tablehash{$_} + 1;
			}
			else
			{
				$tablehash{$_} = 1;
			}
		}

		foreach (keys %tablehash)
		{
			$warn .= "table '$_' : $tablehash{$_}\n" if($tablehash{$_} > 1);
			push @nodupes, $_;
		}
		
		if($warn ne "")
		{
			$warn = "WARNING: Duplicate tables for nodetype " .
				$$TYPE{title} . ":\n" . $warn;

			Everything::printLog($warn);
		}

		# Store the table array in case we need it again.
		$$TYPE{tableArray} = \@nodupes;
	}
	else
	{
		my @emptyArray;
		
		# Just an empty array.
		$$TYPE{tableArray} = \@emptyArray;
	}

	return $$TYPE{tableArray};
}


#############################################################################
#	Sub
#		getMaintenanceCode
#
#	Purpose
#		This finds the code that needs to be executed for the given
#		node and operation.
#
#	Parameters
#		$NODE - a node hash or id of the node being affected
#		$op - the operation being performed (typically 'create', 'update',
#			or 'delete')
#
#	Returns
#		The code to be executed.  0 if no code was found.
#
sub getMaintenanceCode
{
	my ($this, $NODE, $op) = @_;
	my $maintain;
	my $code;
	my %WHEREHASH;
	my $TYPE;
	my $done = 0;
	my $TMP;

	# If the maintenance nodetype has not been loaded, don't try to do
	# any thing (the only time this should happen is when we are
	# importing everything from scratch).
	$TMP = $this->getType("maintenance");
	if( (not defined $TMP) || ($$TMP{extends_nodetype} eq "0") )
	{
		# The 'eq "0"' thing is just checking to see if the references
		# have been fixed.
		return 0;
	}

	$this->getRef($NODE);
	$TYPE = $this->getType($$NODE{type_nodetype});
	
	# Maintenance code is inherited by derived nodetypes.  This will
	# find a maintenance code from parent nodetypes (if necessary).
	do
	{
		undef %WHEREHASH;

		%WHEREHASH = (
			maintain_nodetype => $$TYPE{node_id}, maintaintype => $op);
		
		$maintain = $this->selectNodeWhere(\%WHEREHASH, 
			$this->getType("maintenance"));

		if(not defined $maintain)
		{
			# We did not find any code for the given type.  Run up the
			# inheritance hierarchy to see if we can find anything.
			if($$TYPE{extends_nodetype})
			{
				$TYPE = $this->getType($$TYPE{extends_nodetype});
			}
			else
			{
				# We have hit the top of the inheritance hierarchy for this
				# nodetype and we haven't found any maintenance code.
				return 0;
			}
		}
	} until(defined $maintain);
	
	$code = $this->getNodeById($$maintain[0]);
	return $$code{code};
}



#############################################################################
#	Sub
#		nodeMaintenance
#
#	Purpose
#		Some nodetypes need to do some special stuff when a node is
#		created, updated, or deleted.  Maintenance nodes (similar to
#		htmlpages) can be created to have code that knows how to
#		maintain nodes of that nodetype.  You can kind of think of
#		maintenance pages as constructors and destructors for nodes of
#		a particular nodetype.
#
#	Parameters
#		$node_id -  a node hash or id that is being affected
#		$op - the operation being performed (typically, 'create', 'update',
#			or 'delete')
#
#	Returns
#		0 if error.  1 otherwiwse.
#
sub nodeMaintenance
{
	my ($this, $node_id, $op) = @_;
	my $code;
	
	# NODE and op must be defined!
	return 0 if(not defined $node_id);
	return 0 if((not defined $op) || ($op eq ""));

	# Find the maintenance code for this page (if there is any)
	$code = $this->getMaintenanceCode($node_id, $op);

	if($code)
	{
		$node_id = $this->getId($node_id);
		my $args = "\@\_ = \"$node_id\";\n";
		Everything::HTML::embedCode("%" . $args . $code . "%");
	}
}

#############################################################################
#	Sub
#		getId
#
#	Purpose
#		Opposite of getRef.  This makes sure we have node id's not hashes.
#
#	Parameters
#		Array of node hashes to convert to id's
#
#	Returns
#		An array (if there are more than one to be converted) of node id's.
#
sub getId
{
	my ($this, @args) = @_;
	
	foreach my $arg (@args)
	{
		if (ref $arg eq "HASH") {$arg = $$arg{node_id};}  
	}
	
	return (@args == 1 ? $args[0] : @args);
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
			$_[$i] = $this->getNodeById($_[$i]) if($_[$i]);
		}
	}
	
	ref $_[0];
}


#############################################################################
#	Sub
#		isNodetype
#
#	Purpose
#		Checks to see if the given node is nodetype or not.
#
#	Parameters
#		$NODE - the node to check
#
#	Returns
#		true if the node is a nodetype, false otherwise.
#
sub isNodetype
{
	my ($this, $NODE) = @_;

	$this->isOfType($NODE, 'nodetype');
}


#############################################################################
#	Sub
#		isOfType
#
#	Purpose
#		Checks to see if a node is of a given type.
#
#	Parameters
#		$NODE - the node to check
#		$type - the type name, type id, or type hash to check against
#
#	Returns
#		true if the node is of the given type, false otherwise.
#
sub isOfType
{
	my ($this, $NODE, $type) = @_;

	$this->getRef($NODE);
	
	return 0 if (not ref $NODE);

	# If this node's type is a nodetype, its a nodetype.
	$type = $this->getType($type) if(ref $type ne "HASH");

	return ($$NODE{type_nodetype} == $$type{node_id});
}


#############################################################################
#	Sub
#		isGroup
#
#	Purpose
#		Check to see if a node is a group.  Groups have a value
#		in the grouptable field of their nodetype.
#
#	Parameters
#		$NODE - the node id or hashreference to a node that we wish to see
#			if it is a group node.  This can also be the nodetype hash, if
#			you just want to check to see if nodes of a certain type are
#			groups.  Note, if the NODE passed is a nodetype, the caller
#			is responsible for making sure it is properly derived (called
#			getType() to get the nodetype.
#
#	Returns
#		The name of the grouptable if the node is a group, 0 (false)
#		otherwise.
#
sub isGroup
{
	my ($this, $NODE) = @_;
	my $groupTable;
	my $GROUPTYPE;
	
	$this->getRef($NODE);
	
	$GROUPTYPE = $NODE if($this->isNodetype($NODE));
	$GROUPTYPE ||= $$NODE{type};
	
	$groupTable = $$GROUPTYPE{grouptable};

	return $groupTable if($groupTable && $groupTable ne "");

	return 0;
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
#		$NODE - the node that the user is trying to access.  This can be
#			undef, if the check does not involve a node (like the example
#			above.
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
	my ($this, $USER, $NODE, $permission, $modes) = @_;
	my $PERM = $this->getNode($permission, 'permission');
	my $perms;

	return 0 unless($PERM);

	$perms = eval($$PERM{code});

	return $this->checkPermissions($perms, $modes);
}

#############################################################################
#	Sub
#		hasAccess
#
#	Purpose
#		This checks to see if the given user has the necessary permissions
#		to access the given node.
#
#	Note
#		Passing "c" (create) as one of the modes to a node that is not a
#		nodetype does nothing.  You can only create nodes of a nodetype.
#		So, when you want to see if a user has permission to create a node,
#		you need to pass the nodetype of the node that they wish to create
#
#	Parameters
#		$NODE - the node we are checking access for
#		$USER - the user trying to access the node
#		$modes - the access modes to check for.  This is a string that
#			contain one or more of any of the following characters in any
#			order:
#			'r' (read), 'w' (write), 'd' (delete), 'c' (create),
#			'x' (execute).  For example, "rw" would return 1 (true) if
#			the user has read AND write permissions to the node.  Note that
#			order does not matter.  "rw" will return the same result as "wr".
#
#	Returns
#		1 (true) if the user has access to all modes given.  0 (false)
#		otherwise.  The user must have access for all modes given for this to
#		return true.  For example, if the user has read, write and delete
#		permissions, and the modes passed were "wrx", the return would be
#		0 since the user does not have the "execute" permission.
#
sub hasAccess
{
	my ($this, $NODE, $USER, $modes) = @_;

	# -1 is a way of specifying "super user".
	return 1 if($USER eq "-1");
	
	# Gods always have access to everything
	return 1 if($this->isGod($USER));

	$this->getRef($NODE);
	$this->getRef($USER);

	# Figure out what permissions this user has for this node.
	my $perms = $this->getUserPermissions($NODE, $USER);

	return $this->checkPermissions($perms, $modes);
}


#############################################################################
#	Sub
#		checkPermissions
#
#	Purpose
#		Given the permissions that a user has, and the permissions that
#		they need, return true or false indicating that they have or
#		do not have the needed permissions
#
#	Parameters
#		$perms - the permissions that the user has
#		$modes - the permissions that they need
#
#	Returns
#		1 (true) if the user has all the needed permissions.  0 (false)
#		otherwise
#
sub checkPermissions
{
	my ($this, $perms, $modes) = @_;
	
	# We remove any allowed permissions from the given modes.  We need to do
	# this dymanically (evaled) because tr/// does not interpret variables.
	# So, we need to create some code on the fly.
	my $dynamic = "\$modes =~ tr/$perms//d;";
	
	eval($dynamic);

	# If our string is empty, the user has all the needed permissions.
	return 1 if($modes eq "");

	return 0;
}


#############################################################################
#	Sub
#		getUserPermissions
#
#	Purpose
#		Given the user and a node, this will return what permissions the
#		user has on that node.
#
#	Parameters
#		NODE - The node for which we wish to check permissions
#		USER - The user that to get permissions for.
#
#	Returns
#		A string that contains the permission flags that the user has access.
#		For example, if the user can read and write to the node, the return
#		value will be "rw".  If the user has no permissions for the node, an
#		empty string ("") will be returned.
#
sub getUserPermissions
{
	my ($this, $NODE, $USER) = @_;
	my $perms = $this->getDynamicPermissions($NODE, $USER);
	
	if(not defined $perms)
	{
		my $class = $this->getUserNodeRelation($USER, $NODE);
		$perms = $this->getDefaultPermissions($NODE, $class);
	}
	
	# Remove any '-' chars and spaces, we only want the permissions of those
	# that are on.
	$perms =~ s/[\-\ ]//g;

	return $perms;
}


#############################################################################
#	Sub
#		getUserNodeRelation
#
#	Purpose
#		Every user has some relation to every node.  They are either the
#		"author", in the "group", a "guest" user, or "other".  This will
#		return the relation the given user has with the given node.
#
#	Parameters
#		$USER - the user
#		$NODE - the node
#
#	Returns
#		Either "author", "group", "guest", or "other" which can be used to
#		get the appropriate permissions for the user.
#
sub getUserNodeRelation
{
	my ($this, $USER, $NODE) = @_;
	my $class;
	my $userId;
	my $sysSettings = Everything::getVars(
		$this->getNode('system settings', 'setting'));
	my $guest = $$sysSettings{guest_user};
	
	$this->getRef($USER);
	$this->getRef($NODE);
	
	$userId = $this->getId($USER);
	
	# Determine how this user relates to this node.  Is the user
	# the author, in the group, "others", or guest user?
	if($userId == $$NODE{author_user})
	{
		$class = "author";
	}
	elsif($userId == $guest)
	{
		$class = "guest";
	}
	else
	{
		my $usergroup = $this->deriveUsergroup($NODE);
		
		if(($usergroup > 0) && $this->inGroup($usergroup, $USER))
		{
			$class = "group";
		}
		else
		{
			# If the user is not the author, in the group, or the guest user
			# for the system, they must be "other".
			$class = "other";
		}
	}

	return $class;
}


#############################################################################
#	Sub
#		deriveUsergroup
#
#	Purpose
#		The usergroup of a node can inherit from its type (specify -1).
#		This returns the group of the node.  Either what it has specified,
#		or what its nodetype defaults to.
#
#	Parameters
#		$NODE - the node in which to get the usergroup for.
#
#	Returns
#		The node id of the usergroup
#
sub deriveUsergroup
{
	my ($NODE) = @_;

	if($$NODE{group_usergroup} != -1)
	{
		return $$NODE{group_usergroup};
	}
	else
	{
		return $$NODE{type}{defaultgroup_usergroup};
	}
}


#############################################################################
#	Sub
#		getDefaultPermissions
#
#	Purpose
#		This takes the given node and returns the permissions for the given
#		class of users.
#
#	Parameters
#		$NODE - the node to get the permissions for
#		$class - the class of permissions to get.  Either "author", "group",
#			"guest", or "other".  This can be obtained from calling
#			getUserNodeRelation().
#
#	Returns
#		A hashref that contains the strings of the permissions.  The
#		strings can contain any of these characters "rwxdc-".
#
sub getDefaultPermissions
{
	my ($this, $NODE, $class) = @_;
	my $TYPE = $$NODE{type};
	my $perms;
	my $parentPerms;
	my $field = $class . "access";
	
	$perms = $$NODE{$field};
	$parentPerms = $this->getDefaultTypePermissions($TYPE, $class);
	$perms = $this->inheritPermissions($perms, $parentPerms);

	return $perms;
}


#############################################################################
#	Sub
#		getDynamicPermissions
#
#	Purpose
#		You can specify a "permission" node to calculate the permissions
#		for a node.  This checks to see if there is a permission for the
#		node.  If so, it evals the permission code and returns the
#		generated permissions.
#
#	Parameters
#		$NODE - the node we need to get the permissions for
#		$USER - the user that is trying gain access
#
#	Returns
#		The permissions flags generated by the permission code
#
sub getDynamicPermissions
{
	my ($this, $NODE, $USER) = @_;
	my $class = $this->getUserNodeRelation($USER, $NODE);
	my $perms;

	my $permission = $$NODE{"dynamic".$class."_permission"};

	if($permission == -1)
	{
		$permission = $$NODE{type}{"default".$class."_permission"};
	}

	if($permission > 0)
	{
		my $PERM = $this->getNodeById($permission);

		if($PERM)
		{
			$perms = eval($$PERM{code});
		}
	}
	
	return $perms;
}


#############################################################################
#	Sub
#		getDefaultTypePermissions
#
#	Purpose
#		This gets the default permissions for the given nodetype.  This
#		is NOT the permissions for the nodetype itself.  Rather, these
#		are the permissions that nodes of this type inherit from.  Hence,
#		the default TYPE permissions.
#
#	Parameters
#		$TYPE - the name, id, or hash of the nodetype to get the default
#			permissions for.
#		$class - the class of user.  Either "author", "group", "guest",
#			or "other".  This can be obtained by calling
#			getUserNodeRelation().
#
#	Returns
#		A string that contains the default permissions of the given
#		nodetype.
#
sub getDefaultTypePermissions
{
	my ($this, $TYPE, $class) = @_;

	# getType() derives nodetypes automatically.  So we just need to get
	# the type and then return the appropriate field.
	$TYPE = $this->getType($TYPE) unless(ref $TYPE eq "HASH");

	my $field = "default" . $class . "access";

	return $$TYPE{$field};
}


#############################################################################
#	Sub
#		inheritPermissions
#
#	Purpose
#		This is just a utility function that takes two strings and combines
#		them in a way such that any 'i' (inherit) flags in the child
#		permssions get over written by the corresponding parent permission.
#
#	Parameters
#		$child - the child permissions
#		$parent - the parent permissions
#
#	Returns
#		A string that contains the merged
#
sub inheritPermissions
{
	my ($this, $child, $parent) = @_;
	my @childperms = split '', $child;
	my @parentperms = split '', $parent;
    my @perms;
	
	foreach my $i (0..@parentperms)
	{
		if($childperms[$i] eq "i")
		{
			# We inherit the parent's setting.
			push @perms, $parentperms[$i]
		}
		else
		{
			# use the child setting.
			push @perms, $childperms[$i];
		}
	}

	return (join('', @perms));
}

#############################################################################
#	DEPRICATED - use inGroup()
sub isApproved { 
	my ($this, $NODE, $GROUP) = @_;
	$this->inGroup($GROUP, $NODE); }

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
#	Sub
#		inGroupFast
#
#	Purpose
#		This just does a brute force check (which happens to be the fastest)
#		to see if a particular node is in a group.
#
#	NOTE!!!
#		This only works for groups that do NOT contain sub groups.  If the
#		group contains sub groups, you will need to use inGroup()
#
#	Parameters
#		GROUP - node id or node hash of the the group in question
#		NODE - the node id or node hash of the node that we wish to check for
#			group membership
#
#	Returns
#		1 (true) if the given node is in the group.  0 (false) otherwise.
#
sub inGroupFast
{
	my ($this, $GROUP, $NODE) = @_;
	my $table;
	
	# Make sure the group node is really a group, and get its group table.
	if(($table = $this->isGroup($GROUP)))
	{
		my $groupId = $this->getId($GROUP);
		my $nodeId = $this->getId($NODE);
		my @match = $this->sqlSelect("node_id", $table,
			$table . "_id=$groupId && node_id=$nodeId" );

		# Note this does not handle sub groups.  If the group contains
		# sub groups you will need to use inGroup
		return 1 if(@match > 0);
	}

	return 0;
}


#############################################################################
#	Sub
#		inGroup
#
#	Purpose
#		This checks to see if the given node belongs to the given group.
#		This will check all sub groups.  If you know for a fact that your
#		group does not contain sub groups, you will probably want to call
#		inGroupFast() instead as it will be significantly faster in most
#		cases.
#
#	Parameters
#		GROUP - node id or node hash of the the group in question
#		NODE - the node id or node hash of the node that we wish to check for
#			group membership
#
#	Returns
#		1 (true) if the given node is in the group.  0 (false) otherwise.
#
sub inGroup
{
	my ($this, $GROUP, $NODE) = @_;
	my $members;
	my $id = $this->getId($NODE);

	return 0 if(not defined $GROUP);
	return 0 if(not defined $NODE);

	$members = $this->selectNodegroupFlat($GROUP);

	foreach my $member (@$members)
	{
		return 1 if($this->getId($member) == $id);
	}

	return 0;
}



#############################################################################
#	Sub
#		isGod
#
#	Purpose
#		Checks to see if a user is in the gods group.  This includes root
#		and '-1' as gods.  This also checks sub groups so you can have
#		other usergroups in the gods group.
#
#	Parameters
#		$USER - an id or HASH ref to a user node.
#
#	Returns
#		1 if the user is a god, 0 otherwise
#
sub isGod
{
	my ($this, $USER) = @_;
	my $GODS;

	# -1 is our internal flag for "superuser"
	return 1 if($USER == -1);

	($GODS) = $this->getNode("gods", $this->getType("usergroup"));

	return $this->inGroupFast($GODS, $USER);
}


#############################################################################
#	Sub
#		selectNodegroupFlat
#
#	Purpose
#		This recurses through the nodes and node groups that this group
#		contains getting the node hash for each one on the way.
#
#	Parameters
#		$NODE - the group node to get node hashes for.
#
#	Returns
#		An array of node hashes that belong to this group.
#
sub selectNodegroupFlat
{
	my ($this, $NODE) = @_;

	return $this->flattenNodegroup($NODE);
}


#############################################################################
#	Sub
#		flattenNodegroup
#
#	Purpose
#		Returns an array of node hashes that all belong to the given
#		group.  If the given node is not a group, its just assumed that
#		a single node is in its own "group".
#
#	Parameters
#		$NODE - the node (preferably a group node) in which to get the
#			nodes that are within its group.
#
#	Returns
#		An array of node hashrefs of all of the nodes in this group.
#
sub flattenNodegroup
{
	my ($this, $NODE, $groupsTraversed) = @_;
	my @listref;
	my $group;

	return undef if (not defined $NODE);

	# If groupsTraversed is not defined, initialize it to an empty
	# hash reference.
	$groupsTraversed ||= {};  # anonymous empty hash

	$this->getRef($NODE);
	
	if ($this->isGroup($NODE))
	{
		# return if we have already been through this group.  Otherwise,
		# we will get stuck in infinite recursion.
		return undef if($$groupsTraversed{$$NODE{node_id}});
		$$groupsTraversed{$$NODE{node_id}} = $$NODE{node_id};
		
		foreach my $groupref (@{ $$NODE{group} })
		{
			$group = $this->flattenNodegroup($groupref);
			push(@listref, @$group) if(defined $group);
		}
		
		return \@listref;
  	}
	else
	{ 
		return [$NODE];
	}
}


#############################################################################
#	Sub
#		insertIntoNodegroup
#
#	Purpose
#		This will insert a node(s) into a nodegroup.
#
#		NOTE!  It appears that inserting into a nodegroup does not
#		update the node itself (the node is added to the group, but
#		the group node is left untouched).  This prevents other httpd
#		processes from knowing that the group has been updated, which
#		means they will probably have stale group info.
#
#	Parameters
#		NODE - the group node to insert the nodes.
#		USER - the user trying to add to the group (used for authorization)
#		insert - the node or array of nodes to insert into the group
#		orderby - the criteria of which to order the nodes in the group
#
#	Returns
#		The group NODE hash that has been refreshed after the insert.
#		undef if the user does not have permissions to change this group.
#
sub insertIntoNodegroup
{
	my ($this, $NODE, $USER, $insert, $orderby) = @_;
	$this->getRef($NODE);
	my $insertref;
	my $groupTable;
	my $rank;	


	return undef unless($this->canUpdateNode ($USER, $NODE)); 
	
	# Make sure this is a group node!
	return undef unless($groupTable = $this->isGroup($NODE));

	if(ref ($insert) eq "ARRAY")
	{
		$insertref = $insert;

		# If we have an array, the order is specified by the order of
		# the elements in the array.
		undef $orderby;
	}
	else
	{
		# converts to a list reference w/ 1 element if we get a scalar
		$insertref = [$insert];
	}
	
	foreach my $INSERT (@$insertref)
	{
		$this->getRef($INSERT);
		my $maxOrderBy;
		
		# This will return a value if the select is not empty.  If
		# it is empty (there is nothing in the group) it will be null.
		($maxOrderBy) = $this->sqlSelect('MAX(orderby)', $groupTable, 
			$groupTable . "_id=$$NODE{node_id}"); 

		if (defined $maxOrderBy)
		{
			# The group is not empty.  We may need to change some ordering
			# information.
			if ((defined $orderby) && ($orderby <= $maxOrderBy))
			{ 
				# The caller of this function specified an order position
				# for the new node in the group.  We need to make a spot
				# for it.  To do this, we will increment each orderby
				# field that is the same or higher than the orderby given.
				# If orderby is greater than the current max orderby, we
				# don't need to do this.
				$this->sqlUpdate($groupTable, { '-orderby' => 'orderby+1' }, 
					$groupTable. "_id=$$NODE{node_id} && orderby>=$orderby");
			}
			elsif(not defined $orderby)
			{
				$orderby = $maxOrderBy+1;
			}
		}
		elsif(not defined $orderby)
		{
			$orderby = 0;  # start it off
		}
		
		$rank = $this->sqlSelect('MAX(rank)', $groupTable, 
			$groupTable . "_id=$$NODE{node_id}");

		# If rank exists, increment it.  Otherwise, start it off at zero.
		$rank = ((defined $rank) ? $rank+1 : 0);

		$this->sqlInsert($groupTable, { $groupTable . "_id" => $$NODE{node_id}, 
			rank => $rank, node_id => $$INSERT{node_id},
			orderby => $orderby});

		# if we have more than one, we need to clear this so the other
		# inserts work.
		undef $orderby;
	}
	
	# we should also refresh the group list ref stuff
	$_[1] = $this->getNodeById($NODE, 'force'); #refresh the group
}


#############################################################################
#	Sub
#		removeFromNodegroup
#
#	Purpose
#		Remove a node from a group.
#
#	Parameters
#		$GROUP - the group in which to remove the node from
#		$NODE - the node to remove
#		$USER - the user who is trying to do this (used for authorization)
#
#	Returns
#		The newly refreshed nodegroup hash.  If you had called
#		selectNodegroupFlat on this before, you will need to do it again
#		as all data will have been blown away by the forced refresh.
#
sub removeFromNodegroup 
{
	my ($this, $GROUP, $NODE, $USER) = @_;
	$this->getRef($GROUP);
	my $groupTable;
	my $success;
	
	($groupTable = $this->isGroup($GROUP)) or return; 
	$this->canUpdateNode($USER, $GROUP) or return; 

	my $node_id = $this->getId($NODE);

	$success = $this->sqlDelete ($groupTable,
		$groupTable . "_id=$$GROUP{node_id} && node_id=$node_id");

	if($success)
	{
		# If the delete did something, we need to refresh this group node.	
		$_[1] = $this->getNodeById($GROUP, 'force');
	}

	return $_[1];
}


#############################################################################
#	Sub
#		replaceNodegroup
#
#	Purpose
#		This removes all nodes from the group and inserts new nodes.
#
#	Parameters
#		$GROUP - the group to clean out and insert new nodes
#		$REPLACE - A node or array of nodes to be inserted
#		$USER - the user trying to do this (used for authorization).
#
#	Returns
#		The group NODE hash that has been refreshed after the insert
#
sub replaceNodegroup
{
	my ($this, $GROUP, $REPLACE, $USER) = @_;
	$this->getRef($GROUP);
	my $groupTable;

	$this->canUpdateNode($USER, $GROUP) or return; 
	($groupTable = $this->isGroup($GROUP)) or return; 
	
	$this->sqlDelete ($groupTable, $groupTable . "_id=$$GROUP{node_id}");

	return $this->insertIntoNodegroup ($_[1], $USER, $REPLACE);  
}



#############################################################################
#	End of Package
#############################################################################

1;
