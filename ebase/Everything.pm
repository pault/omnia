package Everything;

#############################################################################
#	Everything perl module.  
#	Copyright 1999 Everything Development
#	http://www.everydevel.com
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
		getRef 
		getId 
		getTables

		getNode
		getNodeById
		getType
		getNodeWhere
		selectNodeWhere

		initEverything
		searchNodeName 

		clearFrontside
		clearBackside
		logErrors
		flushErrorsToBackside
		getFrontsideErrors
		getBacksideErrors

		dumpCallStack
		getCallStack
		printErr
		printLog
		logHash

		@fsErrors
		@bsErrors
        );
 }

use vars qw($DB);

# If you want to log to a different file, change this.
my $everythingLog = "/tmp/everything.errlog";

# Used by Makefile.PL to determine the version of the install.
my $VERSION = 0.8;

# Arrays for error caching
use vars qw(@fsErrors);
use vars qw(@bsErrors);



#############################################################################
#
#   a few wrapper functions for the NodeBase stuff
#	this allows the $DB to be optional for the general node functions
#
sub getNode			{ $DB->getNode(@_); }
sub getNodeById		{ $DB->getNodeById(@_); }
sub getType 		{ $DB->getType(@_); }
sub getNodeWhere 	{ $DB->getNodeWhere(@_); }
sub selectNodeWhere	{ $DB->selectNodeWhere(@_); }
sub getRef			{ $DB->getRef(@_); }
sub getId 			{ $DB->getId(@_); }


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
#	Parameters
#		$long - Pass 1 (true) if you want the time format in a nice text
#			based format (ie 13:45 Wed Mar 15 2000).  If false or undef,
#			the format will be numeric only (ie 13:45 03-15-2000)
#
sub getTime
{
	my ($long) = @_;
	my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	my $str = sprintf("%02d:%02d",$hour,$min);
	
	if($long)
	{
		$str .= " " . ('Sun','Mon','Tue','Wed','Thu','Fri','Sat')[$wday];
		$str .= " " . ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug',
			'Sep','Oct','Nov','Dec')[$mon];
		$str .= " $mday";
		$str .= sprintf(" %d", 1900 + $year);
	}
	else
	{
		$str .= " " . sprintf("%02d",$mon+1) . "-" . sprintf("%02d",$mday) .
			"-" . (1900 + $year);
	}

	return $str;
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


#############################################################################
#	Sub
#		initEverything
#
#	Purpose
#		The "main" function.  Initialize the Everything module.
#
#	Parameters
#		$db - the string name of the database to connect to.
#		$staticNodetypes - (optional) 1 if the system should derive the
#			nodetypes once and cache them.  This will speed performance,
#			but changes to nodetypes will not take effect until the httpd
#			is restarted.  A really good performance enhancement IF the
#			nodetypes do not change.
#
sub initEverything
{
	my ($db, $staticNodetypes) = @_;

	# Make sure that we clear the warnings/errors for this go around.
	clearFrontside();
	clearBackside();

	$DB = new Everything::NodeBase($db, $staticNodetypes);
}


#############################################################################
sub clearFrontside
{
	undef @fsErrors;
}


#############################################################################
sub clearBackside
{
	undef @bsErrors;
}


#############################################################################
sub logErrors
{
	my ($warning, $error, $code, $CONTEXT) = @_;
	my $errors;

	$warning ||= "";
	$error ||= "";
	return if($warning eq "" && $error eq "");
	
	$errors = { 'warning' => $warning, 'error' => $error,
		'code' => $code, 'context' => $CONTEXT };

	push @fsErrors, $errors; 
}


#############################################################################
#	Sub
#		flushErrorsToBackside
#
#	Purpose
#		Ok, what is frontside and backside?  When errors are logged, they
#		are considered to be frontside.  Frontside errors are errors that
#		can be associated with specific nodes on the page (ie an error with
#		a piece of htmlcode, etc).  If a piece of code needs to start a
#		new group of frontside errors, this function should be called.  Any
#		errors that are currently in the frontside cache will be moved to
#		the backside error cache.  This way a new group of frontside errors
#		can be created.
#
#		Backside errors are generally errors that cannot me associated with
#		a specific piece of the page.  These are errors caused by opcodes,
#		evals in Node.pm, or other such cases.  Backside errors get displayed
#		on the page in a location given by the placement of the
#		[<BacksideErrors>] htmlsnippet.
#
sub flushErrorsToBackside
{
	push @bsErrors, @fsErrors;

	clearFrontside();
}


#############################################################################
sub getFrontsideErrors
{
	return \@fsErrors;
}


#############################################################################
sub getBacksideErrors
{
	return \@bsErrors;
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
	my $typestr = '';

	$TYPE=[$TYPE] if (ref($TYPE) ne "ARRAY");

	if(ref($TYPE) eq 'ARRAY' and @$TYPE)
	{
		my $t = shift @$TYPE;
		$typestr .= "AND (type_nodetype = " . getId($t);
		foreach(@$TYPE)
		{
			$typestr .= " OR type_nodetype = ". getId($_);
		}
		
		$typestr.=')';
	}

	my @prewords = split ' ', $searchWords;
	my @words;

	my $NOSEARCH = getNode('nosearchwords', 'setting');
	my $NOWORDS = $NOSEARCH->getVars() if $NOSEARCH;

	foreach (@prewords)
	{
		push(@words, $_) unless (exists $$NOWORDS{lc($_)} or length($_) < 2);
	}

	return unless @words;

	my $match = "";
	foreach my $word (@words)
	{
		$word = lc($word);
		$word =~ s/(\W)/\\$1/gs;
		$word = '[[:<:]]' . $word . '[[:>:]]';
		$word = "(lower(title) rlike " .
			$DB->getDatabaseHandle()->quote($word) . ")";
	}


	$match = '('. join(' + ',@words).')';
	my $cursor = $DB->sqlSelectMany("*, $match AS matchval",
		"node", "$match >= 1 $typestr", "ORDER BY matchval DESC");
	
	my @ret;
	while(my $m = $cursor->fetchrow_hashref)
	{ 
		push @ret, $m;
	}
	
	return \@ret;
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
	my @callStack;
	my $func;
	
	@callStack = getCallStack();
	
	# Pop this function off the stack.  We don't need to see "dumpCallStack"
	# in the stack output.
	pop @callStack;
	
	print "*** Start Call Stack ***\n";
	while($func = pop @callStack)
	{
		print "$func\n";
	}
	print "*** End Call Stack ***\n";
}


#############################################################################
#	
sub getCallStack
{
	my ($package, $file, $line, $subname, $hashargs);
	my @callStack;
	my $i = 0;
	
	while(($package, $file, $line, $subname, $hashargs) = caller($i++))
	{
		# We unshift it so that we can use "pop" to get them in the
		# desired order.
		unshift @callStack, "$file:$line:$subname";
	}

	# Get rid of this function.  We don't need to see "getCallStack" in
	# the stack.
	pop @callStack;

	return @callStack;
}


#############################################################################
sub logCallStack
{
	my @callStack = getCallStack();
	my $func;
	my $str = "Call Stack:\n";
	
	pop @callStack;

	while($func = pop @callStack)
	{
		$str .= $func . "\n";
	}

	printLog($str);
}


#############################################################################
#	Sub
#		logHash
#
#	Purpose
#		Debugging function for dumping the contents of a hash to the log
#		file in a nice readable format.
#
sub logHash
{
	my ($hash) = @_;
	my $str = "$hash\n";

	foreach (keys %$hash)
	{
		$str .= "$_ = $$hash{$_}\n";
	}

	printLog($str);
}


#############################################################################
# end of package
#############################################################################

1;
