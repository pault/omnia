package Everything;

#############################################################################
#	Everything perl module.  
#	Copyright 1999 - 2002 Everything Development
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
use Everything::NodeBase::mysql;

use vars qw($DB $VERSION);

# If you want to log to a different file, change this.
my $everythingLog = "/tmp/everything.errlog";

# Used by Makefile.PL to determine the version of the install.
$VERSION = 'pre-1.0';

# Arrays for error caching
use vars qw(@fsErrors);
use vars qw(@bsErrors);

use vars qw(%NODEBASES);

# Are we being run from the command line?
use vars qw($commandLine);

sub BEGIN
{
	use Exporter ();
	use vars	   qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS);
	@ISA=qw(Exporter);
	@EXPORT=qw(
		$DB
		getParamArray
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
	
	# This will be true if we are being run from a command line, in which
	# case all errors should be printed to STDOUT
	$commandLine = (-t STDIN && -t STDOUT);
}


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
#		Debugging utility that will write the given string to the everything
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

	if (open(ELOG, "> $everythingLog")) {	
		print ELOG "$time: Everything log cleared";
	}
}


#############################################################################
#	Sub
#		getParamArray
#
#	Purpose
#		This function allows your other functions to accept either an
#		array of values, or a hash of "-name => value" pairs.  Just call
#		this function with the order of parameters (in case @_ is an
#		array), and @_.  This will parse everything apart and return
#		a hashref that contains paramName => value no matter if the
#		@_ is an array or hash.
#
#	Parameters
#		$names - a string of parameter names that also defines the order
#			of the parameters if a hash is passed.
#		@_ - the parameters passed to your function
#
#	Returns
#		An array of the parameters.  For example, if your function is:
#			myfunc(name, age, weight, height);
#		You would use this function like:
#			my $params = getParamArray("name, age, weight, height", @_);
#		This would then return to you an array of the values in the order
#		specified, no matter if they were originally passed as an array,
#		or a "-name => value" pair list.
#
sub getParamArray
{
	my $names = shift;
	my $first = $_[0];

	if($first =~ /^-/)
	{
		# The first parameter starts with a '-'.  This indicates that
		# @_ is a hash/value pair.  We need to convert this into an
		# array based on the order specified.
		my %hash = @_;
		return @hash{ map { "-$_" } split(/\s*,\s*/, $names) };
	}
	else
	{
		# @_ contains an array of values, just return it
		return @_;
	}
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
	my @delete;

	foreach my $link ('to_node', 'from_node')
	{
		my $cursor = $DB->sqlSelectJoined("$link, node_id", "links",
		{ node => "$link=node_id" });

		if($cursor)
		{
			while(my $row = $cursor->fetchrow_hashref())
			{
				unless ($$row{node_id})
				{
					# No match.  This is a bad link.
					push @delete, { $link => $row->{to_node} };
				}
			}
		}
	}

	foreach my $badlink (@delete)
	{
		$DB->sqlDelete("links", $badlink);
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
#		$options - an optional hash containing one or more of the following:
#		 staticNodetypes - 1 if the system should derive the nodetypes once
#			and cache them.  This will speed performance, but changes
#			to nodetypes will not take effect until the httpd is
#			restarted.  A really good performance enhancement IF the
#			nodetypes do not change. (defaults to 0)
#		 dbtype - the name of the database type to use (defaults to mysql)
#
sub initEverything
{
	my ($db, $options) = @_;

	# Make sure that we clear the warnings/errors for this go around.
	clearFrontside();
	clearBackside();

	unless($DB = $NODEBASES{$db})
	{
		$$options{dbtype} ||= "mysql";
		if ($$options{dbtype} eq "mysql") {
			$DB = new Everything::NodeBase::mysql($db, $$options{staticNodetypes});
		} elsif ($$options{dbtype} eq "Pg") {
			$DB = new Everything::NodeBase::Pg($db, $$options{staticNodetypes});
		} else {
			die "unknown database type $$options{dbtype}";
		}

		# We keep a NodeBase for each database that we connect to. 
		# That way one machine can handle multiple installations in
		# multiple databases, even with different db servers.
		$NODEBASES{$db} = $DB;
	}
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
	
	if($commandLine)
	{
		print "############################################################\n";
		print "Warning: $warning\n";
		print "Error: $error\n";
		print "Code:\n$code\n";
	}
	else
	{
		$errors = { 'warning' => $warning, 'error' => $error,
			'code' => $code, 'context' => $CONTEXT };

		push @fsErrors, $errors; 
	}

	return 1;
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
#		Backside errors are generally errors that cannot be associated with
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
#			particular nodetype).
#
#	Returns
#		A sorted list of node hashes (just the node table info), in
#		order of best matches to worst matches.
#
sub searchNodeName
{
	my ($searchWords, $TYPE) = @_;
	my $typestr = '';

	$TYPE = [$TYPE] if defined $TYPE and $TYPE and ref($TYPE) eq "SCALAR";

	if(ref($TYPE) eq 'ARRAY' and @$TYPE)
	{
		my $t = shift @$TYPE;
		$typestr .= "AND (type_nodetype = " . getId($t);
		foreach(@$TYPE)
		{
			$typestr .= " OR type_nodetype = ". getId($_);
		}
		
		$typestr .= ')';
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
	print "*** Start Call Stack ***\n";

	# remove this call frame, print in order of calling
	my @callStack = getCallStack();
	print "$_\n" for @callStack[reverse (0 .. $#callStack - 1)];

	print "*** End Call Stack ***\n";
}


##############################################################################	
sub getCallStack
{
	my ($package, $file, $line, $subname, $hashargs);
	my @callStack;

	# ignore this frame -- we don't need to see "getCallStack" in the stack.
	my $i = 1;
	
	while(($package, $file, $line, $subname, $hashargs) = caller($i++))
	{
		# We unshift it so that we can use "pop" to get them in the
		# desired order.
		unshift @callStack, "$file:$line:$subname";
	}

	return @callStack;
}


#############################################################################
sub logCallStack
{
	my @callStack = getCallStack();
	my $func;
	my $str = "Call Stack:\n";
	
	# report stack in reverse order, skipping current frame 
	$str .= "$_\n" for (@callStack[reverse(1 .. $#callStack)]);
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
