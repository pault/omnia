package Everything;

#############################################################################
#	Everything perl module.  
#
# 	BSI -- Nate Oostendorp <nate@oostendorp.net> 
#
#	Format: tabs = 4 spaces
#
#	General Notes
#		Functions that start with 'select' only return the node id's.
#		Functions that start with 'get' return node hashes.
#
#############################################################################

use strict;
use DBI;
use Everything::NodeCache;

sub BEGIN
{
	use Exporter ();
	use vars	   qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		$nodeCache
		%NODETYPES
		$dbh
		sqlConnect 
		loadTypes 
		getRef 
		getId 
		getTables
		getFields
		getFieldsHash
		getNodeById
		getNode
		selectNode 
		selectNodeWhere 
		selectNodeByName 
		selectNodegroupFlat 
		removeFromNodegroup 
		replaceNodegroup
		insertIntoNodegroup 
		canCreateNode 
		canDeleteNode 
		canUpdateNode 
		canReadNode 
		updateLinks 
		updateHits 
		nukeNode 
		getVars 
		setVars 
		selectLinks 
		insertNode 
		updateNode 
		printNode 
		searchNodeName 
		getNodeWhere
		isGroup
		isNodetype
		isCore
		lockNode
		unlockNode
		dumpCallStack
		getNodetypeTables
		tableExists
		createNodeTable
		dropNodeTable
		addFieldToTable
		dropFieldFromTable
        node2mail);
 }

use vars qw($nodeCache);
use vars qw(%NODETYPES);
use vars qw($dbname); #the name of the database we're connected to
use vars qw($dbh);

# If you want to log to a different file, change this.
my $everythingLog = "/tmp/everything.errlog";


#############################################################################
sub printErr {
	print STDERR $_[0]; 
}


#############################################################################
#	Sub
#		getTime
#
#	Purpose
#		Quickie function to get a date and time string in a nice format.
#
sub getTime
{
	my $time = `date +"%a %b %d %R%p"`;
	chomp $time;
	return $time;
}


#############################################################################
#	Sub
#		printLog
#
#	Purpose
#		Debugging utiltiy that will write the given string to the everything
#		log (aka "elog").  Each entry is prefixed with the time and date
#		to make for easy debugging.
#
#	Parameters
#		entry - the string to print to the log.  No ending carriage return
#			is needed.
#
sub printLog
{
	my $entry = $_[0];
	my $time = getTime();
	
	# prefix the date a time on the log entry.
	$entry = "$time: $entry\n";

	if(open(ELOG, ">> $everythingLog"))
	{
		print ELOG $entry;
		close(ELOG);
	}

	return 1;
}


#############################################################################
#	Sub
#		clearLog
#
#	Purpose
#		Clear the gosh darn log!
#
sub clearLog
{
	my $time = getTime();

	`echo "$time: Everything log cleared" > $everythingLog`;
}


#############################################################################
#	Sub
#		sqlConnect
#
#	Purpose
#		Connect to that sql database.  Everything.pm stays connected to
#		the database and remembers what database is used.  If a new
#		database is specified, we close the connection to the old one.
#
#	Parameters
#		$db - name of the database to connect to (ie everyalpha)
#
#	Returns
#		True (1) if the connection was made to a new/different database.
#		False (0) if the connection did not change.
#
sub sqlConnect
{
	my ($db) = @_;
	
	if((defined $dbname) && ($dbname eq $db) && (defined $dbh))
	{
		return 0; # nothing to do.
	}
	elsif(defined $dbh)
	{
		# If $dbh is defined, we have an old connection to close.
		$dbh->disconnect();
	}
	
	$dbh = DBI->connect("DBI:mysql:$db", "root", "");
	printLog("database changed to $db");

	$dbname = $db;
		
	return 1;
}


#############################################################################
#	Sub
#		sqlDelete
#
#	Purpose
#		Quickie wrapper for deleting a row from a specified table.
#
#	Parameters
#		from - the sql table to delete the row from
#		where - what the sql query should match when deleting.
#
#	Returns
#		0 (false) if the sql command fails, 1 (true) if successful.
#
sub sqlDelete
{
	my ($from, $where) = @_;

	$where or return;

	my $sql .= "DELETE FROM $from ";
	$sql .= "WHERE $where";

	unless ($dbh->do($sql))
	{  
		printErr "sqlDelete failed: $sql";
		return 0;
	}
	
	1;
}


#############################################################################
#	Sub
#		sqlSelectMany
#
#	Purpose
#		A general wrapper function for a standard SQL select command.
#
#	Parameters
#		select - what colums to return from the select (ie "*")
#		from - the table to do the select on
#		where - the search criteria
#		other - any other sql options thay you may wan to pass
#
#	Returns
#		The sql cursor of the select.  Call fetchrow() on it to get
#		the selected rows.  0 (false) if error.
#
sub sqlSelectMany
{
	my($select,$from,$where,$other)=@_;

	my $sql="SELECT $select ";
	$sql.="FROM $from " if $from;
	$sql.="WHERE $where " if $where;
	$sql.="$other" if $other;
	my $c=$dbh->prepare($sql);
	if($c->execute()) {
		return $c;
	} else {
		printErr "sqlSelectMany Error: $sql";
		return 0;
	}
}


#############################################################################
#	Sub
#		sqlSelect
#
#	Purpose
#		Wrapper for the SQL select command that returns one row.
#
#	Parameters
#		select - the columns to return from the select
#		from - the table to do the select on
#		where - the conditional constraints on the select
#		other - any other select options you may want to add.
#
#	Returns
#		An array if there were more than one column returned.
#		A scalar if only one column.  0 (false) if error.
#
sub sqlSelect
{
	my ($select, $from, $where, $other)=@_;
	my $sql="SELECT $select ";
	$sql.="FROM $from " if $from;
	$sql.="WHERE $where " if $where;
	$sql.="$other" if $other;
	my $c=$dbh->prepare_cached($sql);
	if(not $c->execute()) {
		printErr "sqlSelect Error: $sql";
		return 0;
	}
	my @r=$c->fetchrow();
	$c->finish();

	(@r == 1)?$r[0]:@r;
}


#############################################################################
#	Sub
#		sqlSelectHashref
#
#	Purpose
#		Select a row as a hash and return the reference to that hash.
#
#	Parameters
#		See sqlSelect.
#
#	Returns
#		A hashref to the row
#
sub sqlSelectHashref
{
	my ($select, $from, $where, $other)=@_;
	my $cursor;
	my $ROW;

	my $sql="SELECT $select ";
	$sql.="FROM $from " if $from;
	$sql.="WHERE $where " if $where;
	$sql.="$other" if $other;

	$cursor = $dbh->prepare_cached($sql);
	
	unless ($cursor->execute())
	{
		printErr "sqlSelectHashref Error: $sql";
		return 0;
	}

	$ROW = $cursor->fetchrow_hashref();
	$cursor->finish();

	return $ROW;
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
	my($table,$data,$where)=@_;
	my $sql="UPDATE $table SET";


	return unless keys %$data;

	foreach (keys %$data)
	{
		if (/^-/)
		{
			s/^-//; 
			$sql .="\n  $_ = " . $$data{'-'.$_} . ",";
		}
		else
		{ 
			$sql .="\n  $_ = " . $dbh->quote($$data{$_}) . ",";
		}
	}

	chop($sql);

	$sql.="\nWHERE $where\n" if $where;

	$dbh->do($sql) or (printErr "sqlUpdate failed:\n $sql\n" and return 0);
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
#			pairs.
#
#	Returns
#		true if successful, false otherwise.
#
sub sqlInsert
{
	my($table,$data)=@_;
	my($names,$values);

	foreach (keys %$data) {
		if (/^-/) {$values.="\n  ".$$data{$_}.","; s/^-//;}
		else { $values.="\n  ".$dbh->quote($$data{$_}).","; }
		$names.="$_,";
	}

	chop($names);
	chop($values);

	my $sql="INSERT INTO $table ($names) VALUES($values)\n";

	$dbh->do($sql) or (printErr "sqlInsert failed:\n $sql" and return 0);
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
	for (my $i = 0; $i < @_; $i++)
	{ 
		unless (ref ($_[$i]))
		{
			$_[$i] = getNodeById($_[$i]) if $_[$i];
		}
	}
	
	ref $_[0];
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
	my @args = @_;
	
	foreach my $arg (@args)
	{
		if (ref $arg eq "HASH") {$arg = $$arg{node_id};}  
	}
	
	return (@args == 1 ? $args[0] : @args);
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
	my ($NODE) = @_;
	getRef $NODE;
	
	return 0 if (not ref $NODE);

	# If this node's type is a nodetype, its a nodetype.
	return ($$NODE{type_nodetype} == $NODETYPES{nodetype}{node_id});
}


#############################################################################
#	Sub
#		isGroup
#
#	Purpose
#		Check to see if a nodetpye is a group.  Groups have a value
#		in the grouptable field.
#
#	Parameters
#		$NODETYPE - the node hash or hashreference to a nodetype node.
#
#	Returns
#		The name of the grouptable if the nodetype is a group, 0 (false)
#		otherwise.
#
sub isGroup
{
	my ($NODETYPE) = $_[0];
	my $groupTable;
	getRef $NODETYPE;
	
	$groupTable = $$NODETYPE{grouptable};

	return $groupTable if($groupTable);

	return 0;
}


#############################################################################
#	Sub
#		escape
#
#	Purpose
#		This encodes characters that may interfere with HTML/perl/sql
#		into a hex number preceeded by a '%'.  This is the standard HTML
#		thing to do when uncoding URLs.
#
#	Parameters
#		$esc - the string to encode.
#
#	Returns
#		Then escaped string
#
sub escape
{
	my ($esc) = @_;

	$esc =~ s/(\W)/sprintf("%%%x",ord($1))/ge;
	
	return $esc;
}


#############################################################################
#	Sub
#		unescape
#
#	Purpose
#		Convert the escaped characters back to normal ascii.  See escape().
#
#	Parameters
#		An array of strings to convert
#
#	Returns
#		Nothing useful.  The array elements are changed.
#
sub unescape
{
	foreach my $arg (@_)
	{
		tr/+/ /;
		$arg =~ s/\%(..)/chr(hex($1))/ge;
	}
	
	1;
}


#############################################################################
sub getVars 
{
	my ($NODE) = @_;
	getRef $NODE;

	return if ($NODE == -1);
	
	unless (exists $$NODE{vars}) {
		warn ("getVars:\t'vars' field does not exist for node ".getId($NODE)."
		perhaps it doesn't join on the settings table?\n");
	}
	my %vars;
	return \%vars unless ($$NODE{vars});

	%vars = map { split /=/ } split (/&/, $$NODE{vars});
	foreach (keys %vars) {
		unescape $vars{$_};
		if ($vars{$_} eq ' ') { $vars{$_} = ""; }
	}

	\%vars;
}


#############################################################################
#	Sub
#		setVars
#
#	Purpose
#		This takes a hash of variables and assigns it to the 'vars' of the
#		given node.  If the new vars are different, we will update the
#		node.
#
#	Parameters
#		$NODE - a node id or hash of a node that joins on the
#		"settings" table which has a "vars" field to assign the vars to.
#		$varsref - the hashref to get the vars from
#
#	Returns
#		Nothing
#
sub setVars
{
	my ($NODE, $varsref) = @_;
	my $str;

	getRef $NODE;

	unless (exists $$NODE{vars}) {
		warn ("setVars:\t'vars' field does not exist for node ".getId($NODE)."
		perhaps it doesn't join on the settings table?\n");
	}
	# Clean out the keys that have do not have a value.
	foreach (keys %$varsref) {
		$$varsref{$_} = " " unless $$varsref{$_};
	}
	
	$str = join("&", map( $_."=".escape($$varsref{$_}), keys %$varsref) );

	return unless ($str ne $$NODE{vars}); #we don't need to update...

	# The new vars are different from what this user node contains, force
	# an update on the user info.
	$$NODE{vars} = $str;
	my $superuser = -1;
	updateNode($NODE, $superuser);
}


#############################################################################
sub canCreateNode {
	#returns true if nothing is set
	my ($USER, $TYPE) = @_;
	getRef $TYPE;

	return 1 unless $$TYPE{writers_user};	
	isApproved ($USER, $$TYPE{writers_user});
}


#############################################################################
sub canDeleteNode {
	#returns false if nothing is set (except for SU)
	my ($USER, $NODE) = @_;
	getRef $NODE;

	return 0 if((not defined $NODE) || ($NODE == 0));
	return isApproved ($USER, $$NODE{type}{deleters_user});
}


#############################################################################
sub canUpdateNode {
	my ($USER, $NODE) = @_;
	getRef $NODE;
	
	return 0 if((not defined $NODE) || ($NODE == 0));
	return isApproved ($USER, $$NODE{author_user});
}


#############################################################################
sub canReadNode { 
	#returns true if nothing is set
	my ($USER, $NODE) = @_;
	getRef $NODE;

	return 0 if((not defined $NODE) || ($NODE == 0));
	return 1 unless $$NODE{type}{readers_user};	
	isApproved ($USER, $$NODE{type}{readers_user});
}


#############################################################################
#	Sub
#		selectNode
#
#	Purpose
#		Deprecated.  Use getNodeById.
#
sub selectNode
{
	my ($N, $selectop) = @_;

	return getNodeById($N, $selectop);
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
	my ($N, $selectop) = @_;
	my $groupTable;
	my $NODETYPE;
	my $NODE;
	my $table;

	return -1 if ((not ref $N) and $N eq "-1");
	
	$selectop ||= '';
	my $node_id = getId($N);
	return unless $node_id;

	my $cachedNode;
	
	$cachedNode = $nodeCache->getCachedNodeById($node_id)
		if(defined $nodeCache);

	unless ($selectop eq 'force' or not $cachedNode)
	{
		return $cachedNode;
	}
	
	$NODE = sqlSelectHashref('*', 'node', "node_id=$node_id");
	if(not defined $NODE)
	{
		# the select resulted in no matches.
		return 0;
	}
	
	$NODETYPE = $NODETYPES{$$NODE{type_nodetype}};
	if (not defined $NODETYPE)
	{
		# Why would we ever get here?  All nodetypes are cached.
		printLog("Got an invalid nodetype in getNodeById()");
		return 0;
	}

	$$NODE{type} = $NODETYPE;

	if ($selectop eq 'light')
	{
		# Note that we do not cache the node.  We don't want to cache a
		# node that does not have its table data (its not complete).
		return $NODE;
	}

	# Run through the array of tables and add each one to the node.
	# This is like joining on each table, be we are doing it manually
	# instead, because we already get the node table info.
	foreach $table (@{$$NODETYPE{tableArray}})
	{
		my $DATA = sqlSelectHashref('*', $table,
			"$table" . "_id=$$NODE{node_id}");
		
		if ($DATA)
		{
			foreach (keys %$DATA)
			{
				$$NODE{$_} = $$DATA{$_};
			}
		}
	}
	
	# Make sure each field is at least defined to be nothing.
	foreach (keys %$NODE) {
		$$NODE{$_} = "" unless defined ($$NODE{$_});
	}

	# Fill out the group in the node, if its a group node.
	loadGroupNodeIDs($NODE);

	# Store this node in the cache.
	$nodeCache->cacheNode($NODE) if(defined $nodeCache);

	$NODE;
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
	my ($NODE, $hash, $recursive) = @_;
	my $groupTable;

	# If this node is a group node, add the nodes in its group to its array.
	if ($groupTable = isGroup($$NODE{type}))
	{
		my $cursor;
		my $nid;

		if(not defined $$NODE{group})
		{
			$cursor = sqlSelectMany('node_id', $groupTable,
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
#		genWhereString
#
#	Purpose
#		This code was stripped from selectNodeWhere.  This takes a WHERE
#		hash and a string for ordering and generates the appropriate where
#		string to pass along with a select-type sql command.  The code is
#		in this function so we can re-use it.
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
	my ($WHERE, $TYPE, $orderby) = @_;
	my $wherestr;
	
	foreach my $key (keys %$WHERE)
	{
		# if your where hash includes a hash to a node, you probably really
		# want to compare the ID of the node, not the hash reference.
		if (ref ($$WHERE{$key}) eq "HASH")
		{
			$$WHERE{$key} = getId($$WHERE{$key});
		}
		
		# If $key starts with a '-', it means its a single value.
		if ($key =~ /^\-/)
		{ 
			$key =~ s/^\-//;
			$wherestr .= $key . '=' . $$WHERE{'-' . $key}; 
		}
		else
		{
			#if we have a list, we join each item with ORs
			if (ref ($$WHERE{$key}) eq "ARRAY")
			{
				my $LIST = $$WHERE{$key};
				my $item = shift @$LIST;
				
				if (ref ($item) eq "HASH") { $item = getId $item; }
				
				$wherestr .= $key . '=' . $dbh->quote($item); 
				
				foreach my $item (@$LIST)
				{
					if (ref ($item) eq "HASH") { $item = getId $item; }
					$wherestr .= " or " . $key . '=' . $dbh->quote($item); 
				}
			}
			elsif($$WHERE{$key})
			{
				$wherestr .= $key . '=' .  $dbh->quote($$WHERE{$key});
			}
		}
		
		#different elements are joined together with ANDS
		$wherestr .= " && \n";
	}
	
	$wherestr =~ s/\s\W*$//;
	$wherestr .= " && type_nodetype=$$TYPE{node_id}" if $TYPE;

	$wherestr .= " ORDER BY $orderby" if $orderby;
	
	#you will note that this is not a full-featured WHERE generator --
	#there is no way to do "field1=foo OR field2=bar" 
	#you can only OR on the same field and AND on different fields
	#I haven't had to worry about it yet.  That day may come
	
	return $wherestr;
}


#############################################################################
#	Sub
#		selectNodeWhere
#
#	Purpose
#		Select a node based on some kind of criteria.
#
#		XXX - this seems quite inefficient.  We do a huge table join,
#		search, and retrieval only to get the node id's?  Since we have
#		the cursor, why don't we just do a fetchrow_hashref()?  This way
#		we could return the actual nodes instead of the id's.  The person
#		calling this function will probably call selectNode on each of
#		them anyway, which is just more sql queries.
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
#		A reference to an array of integer node id's that match the query.
#
sub selectNodeWhere
{
	my ($WHERE, $TYPE, $orderby) = @_;
	my $cursor;
	my $select;
	my @nodelist;
	my $node_id;
	

	getRef($TYPE);

	my $wherestr = genWhereString($WHERE, $TYPE, $orderby);

	# We need to generate an sql join command that has the potential
	# to join on multiple tables.  This way the SQL engine does the
	# search for us.
	$select = "SELECT node_id FROM node";

	# Now we need join on the appropriate tables.
	if(($TYPE) && (defined $TYPE) && (ref $$TYPE{tableArray}))
	{
		my $tableArray = $$TYPE{tableArray};
		my $table;
		
		foreach $table (@$tableArray)
		{
			$select .= " LEFT JOIN $table ON node_id=" . $table . "_id";
		}
	}

	$select .= " WHERE " . $wherestr if($wherestr);

	$cursor = $dbh->prepare($select);
	$cursor->execute() or die "SQL Select failed on table join\n$select\n";
	
	while (($node_id) = $cursor->fetchrow)
	{ 
		push @nodelist, $node_id; 
	}
	
	$cursor->finish();
	
	return unless (@nodelist);
	
	return \@nodelist;
}


#############################################################################
#	Sub
#		insertIntoNodegroup
#
#	Purpose
#		This will insert a node(s) into a nodegroup.
#
#	Parameters
#		NODE - the group node to insert the nodes.
#		USER - the user trying to add to the group (used for authorization)
#		insert - the node or array of nodes to insert into the group
#		orderby - the criteria of which to order the nodes in the group
#
#	Returns
#		The group NODE hash that has been refreshed after the insert
#
sub insertIntoNodegroup
{
	my ($NODE, $USER, $insert, $orderby) = @_;
	getRef $NODE;
	my $insertref;
	my $TYPE;
	my $groupTable;
	my $rank;	


	return unless(canUpdateNode ($USER, $NODE)); 
	
	$TYPE = $$NODE{type};
	$groupTable = isGroup($TYPE);

	# We need a nodetype, darn it!
	if(not defined $TYPE)
	{
		printLog("insertIntoNodegroup: no nodetype!!!");
		return 0;
	}
	elsif(not $groupTable)
	{
		printLog("insertIntoNodegroup: the node is not a group node!");
		return 0;
	}

	if(ref ($insert) eq "ARRAY")
	{
		$insertref = $insert;

		# If we have an array, the order is specified by the order of
		# the elements in the array.
		undef $orderby;
	}
	else
	{
		#converts to a list reference w/ 1 element if we get a scalar
		$insertref = [$insert];
	}
	
	foreach my $INSERT (@$insertref)
	{
		getRef $INSERT;
		my $maxOrderBy;
		
		# This will return a value if the select is not empty.  If
		# it is empty (there is nothing in the group) it will be null.
		($maxOrderBy) = sqlSelect('MAX(orderby)', $groupTable, 
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
				sqlUpdate($groupTable, { '-orderby' => 'orderby+1' }, 
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
		
		$rank = sqlSelect('MAX(rank)', $groupTable, 
			$groupTable . "_id=$$NODE{node_id}");

		# If rank exists, increment it.  Otherwise, start it off at zero.
		$rank = ((defined $rank) ? $rank+1 : 0);

		sqlInsert($groupTable, { $groupTable . "_id" => $$NODE{node_id}, 
			rank => $rank, node_id => $$INSERT{node_id},
			orderby => $orderby});

		# if we have more than one, we need to clear this so the other
		# inserts work.
		undef $orderby;
	}
	
	#we should also refresh the group list ref stuff
	$_[0] = selectNode $NODE, 'force'; #refresh the group
}



#############################################################################
#	Sub
#		getNodeWhere
#
#	Purpose
#		selectNodeWhere returns an array of node id's.  We want to have
#		an array of node hashes.  This will give load the nodes that
#		match the sql query into hashes.
#
#	Parameters
#		$WHERE - a hash reference of field=value for the 'where' part of
#			the sql query.
#		$TYPE - a hash reference to the nodetype we are looking for.  If
#			this is not given the search will only be done on the 'node'
#			table since we don't know which tables to join on.
#		$orderby - a string to create the 'orderby' section of the sql.
#		$selectop - The select operation to do.  See getNodeById.
#
#	Returns
#		An array of node hashes that matched the given query.
#
sub getNodeWhere
{
	my ($WHERE, $TYPE, $orderby, $selectop) = @_;

	# DPB - selectNodeWhere has the potential to return the hashes.
	# Maybe we should just modify it to take a parameter as to whether
	# you want IDs or hashes of nodes.  It would save some sql queries.
	my $ret = selectNodeWhere $WHERE, $TYPE, $orderby;

	return unless ref $ret;
	
	foreach (@$ret) {
		$_ = getNodeById $_, $selectop;
	}
	
	@$ret;
}

######################################################################
#	sub 
#		getNode
#
#	purpose
#		much of the time my getNodeWhere queries look like:
#		getNodeWhere({title=>$title}, $NODETYPES{$type});
#		this is basically a shortcut so I can just say
#		getNode($title, $type);
#
sub getNode {
	my ($title, $type) = @_;
	
	return getNodeById($title) if not $type and $title =~ /^\d+$/;
	
	my @ret = getNodeWhere({title=>$title}, $NODETYPES{$type});
	return $ret[0] if @ret;
	"";
}

#############################################################################
#	Sub
#		getNodeRecurse
#
#	Purpose
#		Node groups can contain other node groups.  This will recurse
#		through each group node that we encounter, converting each node
#		ID into a node hash.
#
#	Parameters
#		$NODE - the group node to start from
#		$groupsTraversed - leave this undefined when calling this
#			function.  This is used internally to prevent infinite
#			recursion.
#	Returns
#		The group node hash passed in, but with the 'group' field
#		filled with an array of node hashes.
#
sub getNodeRecurse
{
	my ($NODE, $groupsTraversed) = @_;

	getRef $NODE;
	
	# If groupsTraversed is not defined, initialize it to an empty
	# hash reference.
	$groupsTraversed ||= {};  # anonymous empty hash

	return $NODE if (ref $NODE ne "HASH");

	if (isGroup($$NODE{type}))
	{
		# return if we have already been through this group.  Otherwise,
		# we will get stuck in infinite recursion.
		return $NODE if($$groupsTraversed{$$NODE{node_id}});

		# Add this group node to the ones we have seen.
		$$groupsTraversed{$$NODE{node_id}} = $$NODE{node_id};
	
		foreach my $groupie (@{ $$NODE{group} })
		{
			getNodeRecurse ($groupie, $groupsTraversed);
		}
	}

	$NODE;
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
	my ($NODE) = @_;
	my $listref;

	return if (not defined $NODE);

	getRef $NODE;
	
	if (isGroup($$NODE{type}))
	{
		foreach my $groupref (@{ $$NODE{group} })
		{
			push @$listref, @{ flattenNodegroup ($groupref) };
		}
		
		return $listref;
  	}
	else
	{ 
		return [$NODE];
	}
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
	my ($NODE) = @_;

	return flattenNodegroup (getNodeRecurse($NODE));
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
	my ($GROUP, $NODE, $USER) = @_;
	getRef $GROUP;
	my $groupTable;
	my $success;
	
	($groupTable = isGroup($$GROUP{type})) or return; 
	canUpdateNode($USER, $GROUP) or return; 

	my $node_id = getId $NODE;

	$success = sqlDelete ($groupTable,
		$groupTable . "_id=$$GROUP{node_id} && node_id=$node_id");

	if($success)
	{
		# If the delete did something, we need to refresh this group node.	
		$_[0] = getNodeById $GROUP, 'force'; #refresh the group
	}

	return $_[0];
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
	my ($GROUP, $REPLACE, $USER) = @_;
	getRef $GROUP;
	my $groupTable;

	canUpdateNode($USER, $GROUP) or return; 
	($groupTable = isGroup($$GROUP{type})) or return; 
	
	sqlDelete ($groupTable, $groupTable . "_id=$$GROUP{node_id}");

	return insertIntoNodegroup ($_[0], $USER, $REPLACE);  
}


#############################################################################
#	Sub
#		updateHits
#
#	Purpose
#		Increment the number of hits on a node.
#
#	Parameters
#		$NODE - the node in which to update the hits on
#
#	Returns
#		The new number of hits
#
sub updateHits
{
	my ($NODE) = @_;
	getRef $NODE;

	my $id = getId $NODE;

	sqlUpdate('node', { -hits => 'hits+1' }, "node_id=$id");

	# We will just do this, instead of doing a complete refresh of the node.
	++$$NODE{hits};
}


#############################################################################
#	Sub
#		udpateLinks
#
#	Purpose
#		A link has been traversed.  If it exists, increment its hit and
#		food count.  If it does not exist, add it.
#
#		DPB 24-Sep-99: We need to better define how food gets allocated to
#		to links.  I think t should be in the system vars somehow.
#
#	Parameters
#		$TONODE - the node the link goes to
#		$FROMNODE - the node the link comes from
#		$type - the type of the link (not sure what this is, as of 24-Sep-99
#			no one uses this parameter)
#
#	Returns
#		nothing of use
#
sub updateLinks
{
	my ($TONODE, $FROMNODE, $type) = @_;

	$type ||= 0;
	$type = getId $type;
	my ($to_id, $from_id) = getId $TONODE, $FROMNODE;

	my $rows = sqlUpdate('links',
			{ -hits => 'hits+1' ,  -food => 'food+1'}, 
			"from_node=$from_id && to_node=$to_id && linktype=" .
			$dbh->quote($type));

	if ($rows eq "0E0") { 
		sqlInsert("links", {'from_node' => $from_id, 'to_node' => $to_id, 
				'linktype' => $type, 'hits' => 1, 'food' => '500' }); 
	}
}


#############################################################################
#	Sub
#		selectLinks - should be named getLinks since it returns a hash
#
#	Purpose
#		Gets an array of hashes for the links that originate from this
#		node (basically, the list of links that are on this page).
#
#	Parameters
#		$FROMNODE - the node we want to get links for
#		$orderby - the field in which the sql should order the list
#
#	Returns
#		A reference to an array that contains the links
#
sub selectLinks
{
	my ($FROMNODE, $orderby) = @_;

	my $obstr = "";
	my @links;
	my $cursor;
	
	$obstr = " ORDER BY $orderby" if $orderby;

	$cursor = sqlSelectMany ("*", 'links',
		"from_node=". $dbh->quote(getId($FROMNODE)) . $obstr); 
	
	while (my $linkref = $cursor->fetchrow_hashref())
	{
		push @links, $linkref;
	}
	
	$cursor->finish;
	
	return \@links;
}


#############################################################################
#	Sub
#		cleanLinks
#
#	Purpose
#		Sometimes the links table gets stale with pointers to nodes that
#		do not exist.  This will go through and delete all of the links
#		rows that point to non-existant nodes.
#
#		NOTE!  If the links table is large, this could take a while.  So,
#		don't be calling this after every node update, or anything like
#		that.  This should be used as a maintanence function.
#
#	Parameters
#		None.
#
#	Returns
#		Number of links rows removed
#
sub cleanLinks
{
	my $select;
	my $cursor;
	my $row;
	my @to_array;
	my @from_array;
	my $badlink;

	$select = "SELECT to_node,node_id from links";
	$select .= " left join node on to_node=node_id";

	$cursor = $dbh->prepare($select);

	if($cursor->execute())
	{
		while($row = $cursor->fetchrow_hashref())
		{
			if(not $$row{node_id})
			{
				# No match.  This is a bad link.
				push @to_array, $$row{to_node};
			}
		}
	}

	$select = "SELECT from_node,node_id from links";
	$select .= " left join node on from_node=node_id";

	$cursor = $dbh->prepare($select);

	if($cursor->execute())
	{
		while($row = $cursor->fetchrow_hashref())
		{
			if(not $$row{node_id})
			{
				# No match.  This is a bad link.
				push @from_array, $$row{to_node};
			}
		}
	}

	foreach $badlink (@to_array)
	{
		sqlDelete("links", { to_node => $badlink });
	}

	foreach $badlink (@from_array)
	{
		sqlDelete("links", { from_node => $badlink });
	}
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
	my ($NODE, $USER) = @_;
	my $tableArray;
	my $table;
	my $result = 0;
	my $groupTable;
	
	getRef ($NODE, $USER);
	
	return unless (canDeleteNode($USER, $NODE));

	# This node is about to be deleted.  Do any maintenance if needed.
	nodeMaintenance($NODE, 'delete');
	
	# Delete this node from the cache that we keep.
	$nodeCache->removeNode($NODE) if(defined $nodeCache);

	$tableArray = $$NODE{type}{tableArray};

	push @$tableArray, "node";  # the node table is not in there.

	foreach $table (@$tableArray)
	{
		$result += $dbh->do("DELETE FROM $table WHERE " . $table . 
			"_id=$$NODE{node_id}");
	}

	pop @$tableArray; # remove the implied "node" that we put on
	
	# Remove all links that go from or to this node that we are deleting
	$dbh->do("DELETE FROM links 
		WHERE to_node=$$NODE{node_id} 
		OR from_node=$$NODE{node_id}");

	# If this node is a group node, we will remove all of its members
	# from the group table.
	if($groupTable = isGroup($$NODE{type}))
	{
		# Remove all group entries for this group node
		$dbh->do("DELETE FROM $groupTable WHERE " . $groupTable . 
			"_id=$$NODE{node_id}");
	}
	
	# This will be zero if nothing was deleted from the tables.
	return $result;
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
#		True if successful, false otherwise.
#
sub updateNode
{
	my ($NODE, $USER) = @_;
	getRef $NODE;
	my %VALUES;
	my $tableArray = $$NODE{type}{tableArray};
	my $table;
	my @fields;
	my $field;

	return 0 unless (canUpdateNode($USER, $NODE)); 

	# Cache this node since it has been updated.  This way the cached
	# version will be the same as the node in the db.
	$nodeCache->cacheNode($NODE) if(defined $nodeCache);

	# The node table is assumed, so its not in the "joined" table array.
	# However, for this update, we need to add it.
	push @$tableArray, "node";

	# We extract the values from the node for each table that it joins
	# on and update each table individually.
	foreach $table (@$tableArray)
	{
		undef %VALUES; # clear the values hash.

		@fields = getFields($table);
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

		sqlUpdate($table, \%VALUES, $table . "_id=$$NODE{node_id}");
	}

	# We are done with tableArray.  Remove the "node" table that we put on
	pop @$tableArray;

	# This node has just been updated.  Do any maintenance if needed.
	# NOTE!  This is turned off for now since nothing uses it currently.
	# (helps performance).  If you need to do some special updating for
	# a particualr nodetype, uncomment this line.
	#nodeMaintenance($NODE, 'update');

	return 1;
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
	my ($title, $TYPE, $USER, $DATA) = @_;
	my $tableArray;
	my $table;
	my $NODE;

	
	$TYPE = $NODETYPES{$TYPE} unless (ref $TYPE);
	#can reference with type name as well as "node"

	unless (canCreateNode($USER, $TYPE)) {
		printErr "$$USER{title} not allowed to create this type of node!";
		return 0;
	}

	if ($$TYPE{restrictdupes})
	{ 
		# Check to see if we already have a node of this title.
		my $DUPELIST = selectNodeByName ($title, $TYPE);

		if ($DUPELIST)
		{
			# A node of this name already exists and restrict dupes is
			# on for this nodetype.  Don't do anything
			return 0;
		}
	}

	sqlInsert("node", 
			{title => $title, 
			type_nodetype => $$TYPE{node_id}, 
			author_user => getId($USER), 
			hits => 0,
			-createtime => 'now()'}); 

	# Get the id of the node that we just inserted.
	my ($node_id) = sqlSelect("LAST_INSERT_ID()");

	# Now go and insert the appropriate rows in the other tables that
	# make up this nodetype;
	$tableArray = $$TYPE{tableArray};
	foreach $table (@$tableArray)
	{
		sqlInsert($table, { $table . "_id" => $node_id });
	}

	$NODE = getNodeById $node_id, 'force';
	
	# This node has just been created.  Do any maintenance if needed.
	# We do this here before calling updateNode below to make sure that
	# the 'created' routines are executed before any 'update' routines.
	nodeMaintenance($NODE, 'create');

	if ($DATA)
	{
		@$NODE{keys %$DATA} = values %$DATA;
		updateNode $NODE, $USER; 
	}

	return $node_id;
}



#this has been replaced by selectNodeWhere, but I leave it in because I like it
sub selectNodeByName
{
	my ($title, $TYPE) = @_;

	selectNodeWhere ({title => $title}, $TYPE);	
}

#these are common words that we don't want to include in our searching
# Should these be stored in a system properties node in the db? DPB 09-14-99
my @nosearchwords = (
		"this",
		"the",
		"there",
		"and",
		"you",
		"are"
		);


#############################################################################
#	Sub
#		getFields
#
#	Purpose
#		Get the field names of a table.
#
#	Parameters
#		$table - the name of the table of which to get the field names
#
#	Returns
#		An array of field names
#
sub getFields
{
	my ($table) = @_;

	return getFieldsHash($table, 0);
}


#############################################################################
#	Sub
#		getFieldsHash
#
#	Purpose
#		Given a table name, returns a list of the fields or a hash.
#
#	Parameters
#		$table - the name of the table to get fields for
#		$getHash - set to 1 if you would also like the entire field hash
#			instead of just the field name. (set to 1 by default)
#
#	Returns
#		Array of field names, if getHash is 1, it will be an array of
#		hashrefs of the fields.
#
sub getFieldsHash
{
	my ($table, $getHash) = @_;
	my $field;
	my @fields;
	my $value;

	$getHash = 1 if(not defined $getHash);
	$table ||= "node";

	my $cursor = $dbh->prepare_cached("show columns from $table");
	$cursor->execute;
	
	while ($field = $cursor->fetchrow_hashref)
	{
		$value = ( ($getHash == 1) ? $field : $$field{Field});
		push @fields, $value;
	}

	@fields;
}


#############################################################################
sub lockNode {
	my ($NODE, $USER)=@_;

	1;
}


#############################################################################
sub unlockNode {
	my ($NODE, $USER)=@_;


	1;
}



#############################################################################
#	Sub
#		loadTypes
#
#	Purpose
#		This function creates the nodetypes hash, a convienient way of
#		handling types.  The type nodehashes can be referenced by title
#		or by node_id.
#
#	Parameters
#		None
#
#	Returns
#		Reference to the generated hash.
#
sub loadTypes
{
	my $cursor;
	my $node;
	my $blah;

	undef %NODETYPES;

	printLog("loading nodetypes");

	# First, we need to load the nodetype nodetype (no I'm not studdering).
	$NODETYPES{nodetype} = sqlSelectHashref('*',
		'node left join nodetype on node_id=nodetype_id',
		'title=' . $dbh->quote("nodetype"));

	# This sets a key for the numeric id.
	$NODETYPES{$NODETYPES{nodetype}{node_id}} = $NODETYPES{nodetype};
	
	# Lastly, make sure the nodetype is properly derived first (this
	# really doesn't do anything since nodetype 'nodetype' is not
	# derived from anything, but it does fill out the tableArray).
	deriveNodetype($NODETYPES{nodetype});

	
	# OK.  Now that we have created the nodetype 'nodetype', we are
	# free to do the rest of them.
	$cursor = sqlSelectMany ('node_id', 'node',
		"type_nodetype=$NODETYPES{nodetype}{node_id}");

	while (my ($node_id) = $cursor->fetchrow)
	{
		my $TYPE = getNodeById $node_id, 'force';

		next if ($$TYPE{title} eq "nodetype");  # We already loaded it.

		$NODETYPES{$$TYPE{title}} = $TYPE;
		$NODETYPES{$node_id} = $TYPE;
	}
	
	$cursor->finish();

	#we have to hard wire nodetype nodetype to be it's own nodetype :)
	$NODETYPES{nodetype}{type} = $NODETYPES{nodetype};

	# Now resolve the inheritance for all of the nodetypes.
	foreach $node (keys %NODETYPES)
	{
		deriveNodetype($NODETYPES{$node});
	}
	
	$_[0] = \%NODETYPES;

	\%NODETYPES;
}


#############################################################################
#	Sub
#		isApproved
#
#	Purpose
#		Checks to see if the given user is approved to modify the nodes.
#
#	Parameters
#		$user - reference to a user node hash  (-1 if super user)
#		$NODE - reference to a nodes to check if the user is approved for
#
#	Returns
#		true if the user is authorized to change the nodes, false otherwise
#
sub isApproved
{
	my ($USER, $NODE) = @_;	
	my $user_id;
	my $usergroup;
	my $GODS;
	my $godgroup;
	my $god;  # he's my god too...
	

	#superuser for scripting
	if ($USER == -1) { return 1; }

	getRef $USER;

	$NODE or return 0;

	# A user is always allowed to view their own node
	if (getId($USER) == getId($NODE)) { return 1; }	

	$user_id = getId $USER;
	$usergroup = $NODETYPES{usergroup};
	($GODS) = getNodeWhere({title => 'gods'}, $usergroup);
	$godgroup = $$GODS{group};
	
	foreach $god (@$godgroup)
	{
		return 1 if ($user_id == getId ($god));
	}
	
	foreach my $approveduser (@{ selectNodegroupFlat $NODE })
	{
		return 1 if ($user_id == getId ($approveduser)); 
	}
	
	return 0;
}


#############################################################################
#	Sub
#		mod_perlInit
#
#	Purpose
#		The "main" function.
#
#	Parameters
#		db - the string name of the database to connect to.
#
sub mod_perlInit
{
	my ($db) = @_;

	# if this is the same db we were connected to last time, we
	# can save some queries...
	if(sqlConnect($db))
	{
		clearLog();
		
		$nodeCache = new Everything::NodeCache(100);
		
		# Load the nodetypes so that we know how to load the rest
		# of the nodes. 
		loadTypes();
		initCache();
	}
}


#############################################################################
#	Sub
#		deriveNodetype
#
#	Purpose
#		Nodetypes can inherit properties from parent nodetypes.  This
#		function takes a reference to a nodetype hash and resolves any
#		inherited properies (like readers, writers, sqltables, etc).
#
#		Note that if the inheritance has already been resolved, this
#		won't do the work again.
#
#	Parameters
#		nodetype - a reference to a nodetype hash.
#
#	Returns
#		Nothing.
#
sub deriveNodetype
{
	my ($NODETYPE) = @_;
	my $field;
	my @tables;
	my $table;
	

	return unless((defined $NODETYPE) && 
		(not defined $$NODETYPE{resolvedInheritance}));

	# Copy the value of 'sqltable' to our list.  The list is used
	# to generate the tableArray.  This way we don't corrupt the
	# actual sqltable field.
	$$NODETYPE{sqltablelist} = $$NODETYPE{sqltable};

	if($$NODETYPE{extends_nodetype} != 0)
	{
		# This nodetype derives from another one.  We need to
		# resolve some properties.
		
		my $PARENT = $NODETYPES{$$NODETYPE{extends_nodetype}};
		
		# Make sure our parent nodetype has resolved its inheritance.
		deriveNodetype($PARENT);
		
		foreach $field (keys %$PARENT)
		{
			# We add some fields that are not apart of the actual
			# node, skip these because they are never inherited
			# anyway. (if more custom fields are added, add them
			# here.  We don't want to inherit them.
			next if( ($field eq "tableArray") ||
			         ($field eq "resolvedInheritance") );
			
			# If a field in a nodetype is '-1', this field is derived from
			# its parent.
			if($$NODETYPE{$field} eq "-1")
			{
				$$NODETYPE{$field} = $$PARENT{$field};
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
		
	# Fill out our table array
	getNodetypeTables($$NODETYPE{node_id});
	
	# We have resolved this node's inheritance.  This is used to mark
	# this nodetype so we don't resolve its inheritance more than once.
	$$NODETYPE{resolvedInheritance} = 1;
}

###########################################################################
#	sub
#		isCore
#
#	purpose
#		tell whether a node is in core or not
#
sub isCore {
	my ($NODE) = @_;
	getRef $NODE;
	return $$NODE{core} if $NODE;
	0;
	#seems stupid, but we'll need to change it later
}

#############################################################################
#	Sub
#		getNodetypeTables
#
#	Purpose
#		The %NODETYPES hash contains what tables we need to join on to get
#		the data for that nodetype.  However, they are stored in a comma
#		delimited format, which isn't easy to use.  This creates an array
#		of table names and stores that array for later use.
#
#	Parameters
#		typeNameOrId - The string name or integer Id of the nodetype
#
#	Returns
#		A reference to an array that contains the names of the tables
#		to join on.  Zero if no array
#
sub getNodetypeTables
{
	my ($typeNameOrId) = @_;
	my $NODETYPE = $NODETYPES{$typeNameOrId};
	my $tables;
	my @tablelist;
	my @nodupes;
	my $warn = "";

	if(defined $$NODETYPE{tableArray})
	{
		# We already calculated this, return it.
		return $$NODETYPE{tableArray};
	}

	$tables = $$NODETYPE{sqltablelist};

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
				$$NODETYPE{title} . ":\n" . $warn;

			printLog($warn);
		}

		# Store the table array in case we need it again.
		$$NODETYPE{tableArray} = \@nodupes;
		
		return \@nodupes;
	}
	else
	{
		my @emptyArray;
		
		# Just an empty array.
		$$NODETYPE{tableArray} = \@emptyArray;
	}
}


#############################################################################
#	Sub
#		searchNodeName
#
#	Purpose
#		This is the node search function.  You give a search string
#		containing the words that you want, and this returns a list
#		of nodes (just the node table info, not the complete node).
#		The list is ordered such that the best matches come first.
#
#		NOTE!!! There are many things we can do in here to beef this
#		up.  Like adding a dictionary check on the words submitted
#		so that if a user can't spell we can at least get what they
#		might mean.
#
#	Parameters
#		$searchWords - the search string to use to find node matches.
#		$TYPE - an array of nodetype IDs of the types that we want to
#			restrict the search (useful for only returning results of a
#			particular nodetype.
#
#	Returns
#		A sorted list of node hashes (just the node table info), in
#		order of best matches to worst matches.
#
sub searchNodeName
{
	my ($searchWords, $TYPE) = @_;
	my $typestr;
	my @words;
	my %matches;
	my @hashlist;
	my @sortedHashList;

	if (ref ($TYPE) ne "ARRAY") { $TYPE = [$TYPE]; }

	while ($_ = shift @$TYPE)
	{
		$typestr .= "type_nodetype=" . getId ($_);
		$typestr .= " or " if (@$TYPE);
	}

	$typestr = " and (" . $typestr . ')' if ($typestr); 

	# To keep our searches sane, we disallow certain words (ie words
	# less than 3 characters long, common words, etc).
	
	# Remove the easy ones first: words that are less than 3 characters long
	$searchWords =~ s/\s\S{1,2}\s//gm;
	
	foreach my $noword (@nosearchwords)
	{
		# For each word that we do not allow searching for, do a search
		# and replace on them to change them to nothing.  They must be
		# stand alone words (whitespace on both sides).  This is a case
		# insensitive search.
		$searchWords =~ s/\s$noword\s//gmi;
	}

	@words = split (' ', $searchWords);

	foreach my $word (@words)
	{	
		my $cursor;
		my $hashref;
		
		$cursor = sqlSelectMany('*', 'node',
			"title like " . $dbh->quote("\%$word\%") . $typestr);

		while ($hashref = $cursor->fetchrow_hashref())
		{ 
			# Buffer out the title so we don't have to worry about start
			# and end of string special cases.
			my $title = " " . $$hashref{title} . " ";
			
			# This makes sure that it matches whole words, not just
			# parts of words (for example, %age% in the sql query will
			# match 'page', 'carnage', etc).  This will filter out the
			# "fake" matches that the sql found.
			if ($title =~ /\s$word\s/im) 
			{
				if($matches{$$hashref{node_id}})
				{
					# This node has already matched, don't put it in the
					# list again, just update its "hits".
					$matches{$$hashref{node_id}}++;
				}
				else
				{
					$matches{$$hashref{node_id}} = 1;
					push @hashlist, $hashref;
				}
			} 
		}

		$cursor->finish;
	}

	# Define our comparison routine for sorting the hashlist.  We
	# want the nodes that matched best first.

	# Sort the list in order of most matches to least matches.
	@sortedHashList = sort
		{ $matches{$$a{node_id}} < $matches{$$b{node_id}} } @hashlist;

	return \@sortedHashList;
}


#############################################################################
#	Sub
#		getTables
#
#	Purpose
#		Get the tables that a particular node(type) needs to join on
#
#	Parameters
#		$NODE - the node we are wanting tables for.
#
#	Returns
#		An array of the table names that this node joins on.
#
sub getTables
{
	my ($NODE) = @_;
	getRef $NODE;
	my $tmpArray = ($$NODE{type}{tableArray});  # Make a copy

	return @$tmpArray;
}


#############################################################################
#	Sub
#		dumpCallStack
#
#	Purpose
#		Debugging utility.  Calling this function will print the current
#		call stack to stdout.  Its useful to see where a function is
#		being called from.
#
sub dumpCallStack
{
	my ($package, $file, $line, $subname, $hashargs);
	my $i = 0;

	print "*** Start Call Stack ***\n";
	while(($package, $file, $line, $subname, $hashargs) = caller($i++))
	{
		print "$file:$line:$subname\n";
	}
	print "*** End Call Stack ***\n";
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
	my ($tableName) = @_;
	my $cursor = $dbh->prepare("show tables");
	my $table;
	my $exists = 0;

	$cursor->execute();
	while((($table) = $cursor->fetchrow()) && (not $exists))
	{
		  $exists = 1 if($table eq $tableName);
	}

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
	my ($table) = @_;
	my $tableid = $table . "_id";
	my $result;
	
	return -1 if(tableExists($table));

	$result = $dbh->do("create table $table ($tableid int(11)" .
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
	my ($table) = @_;
	
	# These are the tables that we don't want to drop.  Dropping one
	# of these, could cause the entire system to break.  If you really
	# want to drop one of these, do it from the command line.
	my @nodrop = (
		"container",
		"document",
		"htmlcode",
		"htmlpage",
		"image",
		"links",
		"maintenance",
		"node",
		"nodegroup",
		"nodelet",
		"nodetype",
		"note",
		"rating",
		"user" );

	foreach (@nodrop)
	{
		if($_ eq $table)
		{
			printLog("WARNING! Attempted to drop core table $table!");
			return 0;
		}
	}
	
	return 0 unless(tableExists($table));

	printLog("Dropping table $table");
	return $dbh->do("drop table $table");
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
	my ($table, $fieldname, $type, $primary, $default) = @_;
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

	$dbh->do($sql);

	if($primary)
	{
		# This requires a little bit of work.  We need to figure out what
		# primary keys already exist, drop them, and then add them all
		# back in with the new key.
		my @fields = getFieldsHash($table);
		my @prikeys;
		my $primaries;
		my $field;

		foreach $field (@fields)
		{
			push @prikeys, $$field{Field} if($$field{Key} eq "PRI");
		}

		$dbh->do("alter table $table drop primary key") if(@prikeys > 0);

		push @prikeys, $fieldname; # add the new field to the primaries

		$primaries = join ',', @prikeys;

		printLog($primaries);

		$dbh->do("alter table $table add primary key($primaries)");
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
	my ($table, $field) = @_;
	my $sql;

	$sql = "alter table $table drop $field";

	return $dbh->do($sql);
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
	my ($NODE, $op) = @_;
	my $maintain;
	my $code;
	my %WHEREHASH;
	my $TYPE;
	my $done = 0;

	# If the maintenance nodetype has not been loaded, don't try to do
	# any thing (the only time this should happen is when we are
	# importing everything from scratch).
	return 0 if(not defined $NODETYPES{maintenance}); 

	getRef $NODE;
	$TYPE = $NODETYPES{$$NODE{type_nodetype}};
	
	# Maintenance code is inherited by derived nodetypes.  This will
	# find a maintenance code from parent nodetypes (if necessary).
	do
	{
		undef %WHEREHASH;

		%WHEREHASH = (
			maintain_nodetype => $$TYPE{node_id}, maintaintype => $op);
		
		$maintain = selectNodeWhere(\%WHEREHASH, $NODETYPES{maintenance});

		if(not defined $maintain)
		{
			# We did not find any code for the given type.  Run up the
			# inheritance hierarchy to see if we can find anything.
			if($$TYPE{extends_nodetype})
			{
				$TYPE = $NODETYPES{$$TYPE{extends_nodetype}};
			}
			else
			{
				# We have hit the top of the inheritance hierarchy for this
				# nodetype and we haven't found any maintenance code.
				return 0;
			}
		}
	} until(defined $maintain);
	
	$code = getNodeById($$maintain[0]);
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
#		maintain nodes of that nodetype.
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
	my ($node_id, $op) = @_;
	my $code;
	
	# NODE and op must be defined!
	return 0 if(not defined $node_id);
	return 0 if((not defined $op) || ($op eq ""));

	# Find the maintenance code for this page (if there is any)
	$code = getMaintenanceCode($node_id, $op);

	if($code)
	{
		$node_id = getId($node_id);
		my $args = "\@\_ = \"$node_id\";\n";
		Everything::HTML::embedCode("%" . $args . $code . "%", @_);
	}
}


#############################################################################
#	Sub
#		initCache
#
#	Purpose
#		The settings for the cache are retrieved from the "cache settings"
#		setting node.  This assumes that the cache has been created.
#
sub initCache
{
	my ($NODE) = getNodeWhere( { "title" => "cache settings" },
		$NODETYPES{setting});
	my $cacheSize;

	# Get the settings from the system
	if(defined $NODE && (ref $NODE eq "HASH"))
	{
		my $vars;

		$vars = getVars($$NODE[0]);
		$cacheSize = $$vars{maxSize} if(defined $vars);
	}
	
	$cacheSize ||= 300;  # default to 300
	$nodeCache->setCacheSize($cacheSize);
}


#############################################################################
# end of package
#############################################################################

1;
