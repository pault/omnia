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
use Everything::NodeBase;

sub BEGIN
{
	use Exporter ();
	use vars	   qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		$DB
		$dbh
		getRef 
		getId 
		getTables

		getNode
		getNodeById
		getType
		getNodeWhere
		selectNodeWhere
		selectNode

		nukeNode
		insertNode
		updateNode

		
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
		getVars 
		setVars 
		selectLinks 
		searchNodeName 
		isGroup
		isNodetype
		isCore
		lockNode
		unlockNode
		dumpCallStack
		printErr
		printLog
        );
 }

use vars qw($DB);

# $dbh is deprecated.  Use $DB->getDatabaseHandle() to get the DBI interface
use vars qw($dbh);

# If you want to log to a different file, change this.
my $everythingLog = "/tmp/everything.errlog";

my $VERSION = 0.8;



#############################################################################
#
#   a few wrapper functions for the NodeBase stuff
#	this allows the $DB to be optional for the general node functions
#
sub getNode { $DB->getNode(@_); }
sub getNodeById { $DB->getNodeById(@_); }
sub getType { $DB->getType(@_); }
sub getNodeWhere { $DB->getNodeWhere(@_); }
sub selectNodeWhere  { $DB->selectNodeWhere(@_); }
sub selectNode { $DB->getNodeById(@_); }

sub nukeNode { $DB->nukeNode(@_);}
sub insertNode { $DB->insertNode(@_); }
sub updateNode { $DB->updateNode(@_); }




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
			$_[$i] = $DB->getNodeById($_[$i]) if $_[$i];
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
	my $TYPE = $DB->getType("nodetype");
	return ($$NODE{type_nodetype} == $$TYPE{node_id});
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
	
	dumpCallStack() if(ref $NODE eq "ARRAY");
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
	$DB->updateNode($NODE, $superuser);
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
		($maxOrderBy) = $DB->sqlSelect('MAX(orderby)', $groupTable, 
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
				$DB->sqlUpdate($groupTable, { '-orderby' => 'orderby+1' }, 
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
		
		$rank = $DB->sqlSelect('MAX(rank)', $groupTable, 
			$groupTable . "_id=$$NODE{node_id}");

		# If rank exists, increment it.  Otherwise, start it off at zero.
		$rank = ((defined $rank) ? $rank+1 : 0);

		$DB->sqlInsert($groupTable, { $groupTable . "_id" => $$NODE{node_id}, 
			rank => $rank, node_id => $$INSERT{node_id},
			orderby => $orderby});

		# if we have more than one, we need to clear this so the other
		# inserts work.
		undef $orderby;
	}
	
	#we should also refresh the group list ref stuff
	$_[0] = $DB->getNodeById($NODE, 'force'); #refresh the group
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

	$success = $DB->sqlDelete ($groupTable,
		$groupTable . "_id=$$GROUP{node_id} && node_id=$node_id");

	if($success)
	{
		# If the delete did something, we need to refresh this group node.	
		$_[0] = $DB->getNodeById($GROUP, 'force'); #refresh the group
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
	
	$DB->sqlDelete ($groupTable, $groupTable . "_id=$$GROUP{node_id}");

	return insertIntoNodegroup ($_[0], $USER, $REPLACE);  
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

	my $rows = $DB->sqlUpdate('links',
			{ -hits => 'hits+1' ,  -food => 'food+1'}, 
			"from_node=$from_id && to_node=$to_id && linktype=" .
			$DB->getDatabaseHandle()->quote($type));

	if ($rows eq "0E0") { 
		$DB->sqlInsert("links", {'from_node' => $from_id, 'to_node' => $to_id, 
				'linktype' => $type, 'hits' => 1, 'food' => '500' }); 
	}
}


#############################################################################
#   Sub
#       updateHits
#
#   Purpose
#       Increment the number of hits on a node.
#
#   Parameters
#       $NODE - the node in which to update the hits on
#
#   Returns
#       The new number of hits
#
sub updateHits
{
	my ($NODE) = @_;
	my $id = $$NODE{node_id};

	$DB->sqlUpdate('node', { -hits => 'hits+1' }, "node_id=$id");

	# We will just do this, instead of doing a complete refresh of the node.
	++$$NODE{hits};
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

	$cursor = $DB->sqlSelectMany ("*", 'links',
		"from_node=". $DB->getDatabaseHandle()->quote(getId($FROMNODE)) .
		$obstr); 
	
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

	$cursor = $DB->getDatabaseHandle()->prepare($select);

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

	$cursor = $DB->getDatabaseHandle()->prepare($select);

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
		$DB->sqlDelete("links", { to_node => $badlink });
	}

	foreach $badlink (@from_array)
	{
		$DB->sqlDelete("links", { from_node => $badlink });
	}
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
	$usergroup = $DB->getType("usergroup");
	($GODS) = $DB->getNodeWhere({title => 'gods'}, $usergroup);
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
#		initEverything
#
#	Purpose
#		The "main" function.  Initialize the Everything module.
#
#	Parameters
#		db - the string name of the database to connect to.
#
sub initEverything
{
	my ($db) = @_;

	$DB = new Everything::NodeBase($db);

	# This is for legacy code.  You should not use $dbh!  Use
	# $DB->getDatabaseHandle() going forward.
	$dbh = $DB->getDatabaseHandle();
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
sub searchNodeName {
	my ($searchWords, $TYPE) = @_;
	my $typestr = '';

	$TYPE=[$TYPE] if (ref($TYPE) eq 'HASH');

	if(ref($TYPE) eq 'ARRAY' and @$TYPE) {
		my $t = shift @$TYPE;
		$typestr .= "AND (type_nodetype = " . getId($t);
		foreach(@$TYPE) { $typestr .= " OR type_nodetype = ". getId($_); }
		$typestr.=')';
	}
	my @prewords = split ' ', $searchWords;
	my @words;

	my $NOSEARCH = $DB->getNode('nosearchwords', 'setting');
	my $NOWORDS = getVars $NOSEARCH if $NOSEARCH;

	foreach (@prewords) {
		push(@words, $_) unless (exists $$NOWORDS{lc($_)} or length($_) < 2);
	}

	my $match = "";
	foreach my $word (@words) {
		$word = lc($word);
		$word =~ s/(\W)/\\$1/gs;
		$word = '[[:<:]]'.$word.'[[:>:]]';
		$word = "(lower(title) rlike ".$dbh->quote($word).")";
	}
	
	$match = '('. join(' + ',@words).')';
	my $cursor = $DB->sqlSelectMany("*, $match AS matchval",
		"node",
		"$match >= 1 $typestr", "ORDER BY matchval DESC");
	
	my @ret;
	while(my $m = $cursor->fetchrow_hashref) { push @ret, $m; }
	return \@ret;
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
	my @tmpArray = ($$NODE{type}{tableArray});  # Make a copy

	return @tmpArray;
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
# end of package
#############################################################################

1;
