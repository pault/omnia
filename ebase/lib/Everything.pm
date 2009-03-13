package Everything;

#############################################################################
#	Everything perl module.
#	Copyright 1999 - 2003 Everything Development
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
use Scalar::Util 'reftype';
use Everything::NodeBase;
use IO::Interactive qw/is_interactive/;
use Carp;

use vars qw($DB $VERSION);

# If you want to log to a different file, set the env variable
my $everythingLog = $ENV{EVERYTHING_LOG} || "/tmp/everything.errlog";

# Used by Makefile.PL to determine the version of the install.
$VERSION = 'pre-1.0';

# Arrays for error caching
use vars qw(@fsErrors);
use vars qw(@bsErrors);

use vars qw(%NODEBASES);

# Are we being run from the command line?
use vars qw($commandLine);

use base 'Exporter';

our @EXPORT_OK = qw(
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

our %EXPORT_TAGS = ( all => \@EXPORT_OK );

	# This will be true if we are being run from a command line, in which
	# case all errors should be printed to STDOUT
	$commandLine = is_interactive() ? 1 : 0;

#############################################################################
#
#   a few wrapper functions for the NodeBase stuff
#	this allows the $DB to be optional for the general node functions
#
sub getNode         { $DB->getNode(@_); }
sub getNodeById     { $DB->getNode(@_); }
sub getType         { $DB->getType(@_); }
sub getNodeWhere    { $DB->getNodeWhere(@_); }
sub selectNodeWhere { $DB->selectNodeWhere(@_); }
sub getRef          { $DB->getRef(@_); }
sub getId           { $DB->getId(@_); }

#############################################################################
sub printErr
{
	print STDERR $_[0];
}

=cut


=head2 C<getTime>

Quickie function to get a date and time string in a nice format.

=over 4

=item C<$long>

Pass 1 (true) if you want the time format in a nice text based format (i.e.,
Wed Mar 15 13:45:31 2000).  If false or undef, the format will be numeric only
(in ISO format, i.e., 2000-03-15 13:45:31).  This function respects your
timezone setting, so make sure it is accurate.

=back

=cut

sub getTime
{
	my ($long) = @_;

	return scalar gmtime() if $long;

	my ( $sec, $min, $hour, $mday, $month, $year ) = ( gmtime() )[ 0 .. 5 ];
	return sprintf(
		"%04d-%02d-%02d %02d:%02d:%02d",
		$year + 1900,
		$month + 1, $mday, $hour, $min, $sec
	);
}

=cut


=head2 C<printLog>

Debugging utility that will write the given string to the everything log (aka
"elog").  Each entry is prefixed with the time and date to make for easy
debugging.

=over 4

=item * entry

the string to print to the log.  No ending carriage return is needed.

=back

=cut

sub printLog
{
	my ($entry) = @_;

	# prefix the date and time on the log entry
	my $message = getTime() . ": $entry\n";

	if ( open( my $ELOG, '>>', "$everythingLog" ) )
	{
		print $ELOG $message;
	}
	else
	{
		Everything::logErrors( '',
			"Log '$everythingLog' could not be opened: $!\n$message" );
	}
}

=cut


=head2 C<clearLog>

Clear the gosh darn log!

=cut

sub clearLog
{
	my $time = getTime();

	if ( open( my $ELOG, '>', "$everythingLog" ) )
	{
		print $ELOG "$time: Everything log cleared";
	}
	else
	{
		Everything::logErrors( '',
			"Log '$everythingLog' could not be cleared: $!" );
	}
}

=cut



=head2 C<cleanLinks>

Sometimes the links table gets stale with pointers to nodes that do not exist.
This will go through and delete all of the links rows that point to
non-existant nodes.

NOTE!  If the links table is large, this could take a while.  So, don't be
calling this after every node update, or anything like that.  This should be
used as a maintanence function.

Returns number of links rows removed

=cut

sub cleanLinks
{
	my @delete;

	foreach my $link ( 'to_node', 'from_node' )
	{
		my $cursor = $DB->sqlSelectJoined( "$link, node_id",
			"links", { node => "$link=node_id" } );

		if ($cursor)
		{
			while ( my $row = $cursor->fetchrow_hashref() )
			{
				unless ( $$row{node_id} )
				{

					# No match.  This is a bad link.
					push @delete, { $link => $row->{to_node} };
				}
			}
		}
	}

	foreach my $badlink (@delete)
	{
		$DB->sqlDelete( "links", $badlink );
	}
}

=cut


=head2 C<initEverything>

The "main" function.  Initialize the Everything module.

=over 4

=item * $db

the string name of the database to connect to.

=item * $options

an optional hash containing one or more of the following:

=item * staticNodetypes

1 if the system should derive the nodetypes once and cache them.  This will
speed performance, but changes to nodetypes will not take effect until the
httpd is restarted.  A really good performance enhancement IF the nodetypes do
not change. (defaults to 0)

=item * dbtype

the name of the database type to use (defaults to mysql)

=back

=cut

sub initEverything
{
	my ( $db, $options ) = @_;

	$options = {}
		unless defined $options
		and (reftype( $options ) || '' ) eq 'HASH';

	# Make sure that we clear the warnings/errors for this go around.
	clearFrontside();
	clearBackside();

	return $DB if exists $NODEBASES{$db} and $DB = $NODEBASES{$db};

	my $dbtype  = $options->{dbtype} || 'mysql';
	my $package = 'Everything::DB::' . $dbtype;

	( my $module = $package . '.pm' ) =~ s!::!/!g;

	eval
	{
		require $module;
		$DB = Everything::NodeBase->new(
			$db, $options->{staticNodetypes}, $dbtype
		);
	};

	die "Unknown database type '$options->{dbtype}': $@" if $@;

	# We keep a NodeBase for each database that we connect to.
	# That way one machine can handle multiple installations in
	# multiple databases, even with different db servers.
	$NODEBASES{$db} = $DB;
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
	my ( $warning, $error, $code, $CONTEXT ) = @_;
	$warning ||= '';
	$error   ||= '';

	return unless $warning or $error;

	if ($commandLine)
	{
		my $context = join ')(', map { defined $_ ? $_ : 'undef' } CORE::caller;

		$code    = "Code: $code\n"       if $code;
		$error   = "Error: $error\n"     if $error;
		$warning = "Warning: $warning\n" if $warning;

		print "#" x 60, $warning, $error, $code, "($context)\n";
	}
	else
	{
		push @fsErrors,
			{
			code    => $code,
			context => $CONTEXT,
			error   => $error,
			warning => $warning,
			};
	}

	return 1;
}

=cut


=head2 C<flushErrorsToBackside>

Ok, what is frontside and backside?  When errors are logged, they are
considered to be frontside.  Frontside errors are errors that can be associated
with specific nodes on the page (ie an error with a piece of htmlcode, etc).
If a piece of code needs to start a new group of frontside errors, this
function should be called.  Any errors that are currently in the frontside
cache will be moved to the backside error cache.  This way a new group of
frontside errors can be created.

Backside errors are generally errors that cannot be associated with a specific
piece of the page.  These are errors caused by opcodes, evals in Node.pm, or
other such cases.  Backside errors get displayed on the page in a location
given by the placement of the [E<lt>BacksideErrorsE<gt>] htmlsnippet.

=cut

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

=cut


=head2 C<searchNodeName>

This is the node search function.  You give a search string containing the
words that you want, and this returns a list of nodes (just the node table
info, not the complete node).  The list is ordered such that the best matches
come first.

NOTE!!! There are many things we can do in here to beef this up.  Like adding a
dictionary check on the words submitted so that if a user can't spell we can at
least get what they might mean.

=over 4

=item * $searchWords

the search string to use to find node matches.

=item * $TYPE

an array of nodetype IDs of the types that we want to restrict the search
(useful for only returning results of a particular nodetype).

=back

Returns a sorted list of node hashes (just the node table info), in order of
best matches to worst matches.

=cut

sub searchNodeName
{
	my ( $searchWords, $TYPE ) = @_;
	my $typestr = '';

	my $NOSEARCH = getNode( 'stopwords', 'setting' );
	my $NOWORDS = $NOSEARCH ? $NOSEARCH->getVars() : {};

	my @words = grep { length($_) > 2 and !exists $NOWORDS->{ lc($_) } }
		split ' ', $searchWords;

	return unless @words;
	return $DB->search_node_name(\@words, $TYPE);
}

=cut


=head2 C<dumpCallStack>

Debugging utility.  Calling this function will print the current call stack to
STDOUT.  Its useful to see where a function is being called from.

=cut

sub dumpCallStack
{
	print "*** Start Call Stack ***\n";

	# remove this call frame, print in order of calling
	my @callStack = getCallStack();
	print "$_\n" for @callStack[ reverse( 0 .. $#callStack - 1 ) ];

	print "*** End Call Stack ***\n";
}

##############################################################################
sub getCallStack
{
	my ( $package, $file, $line, $subname, $hashargs );
	my @callStack;

	# ignore this frame -- we don't need to see "getCallStack" in the stack.
	my $i = 1;

	while ( ( $package, $file, $line, $subname, $hashargs ) = caller( $i++ ) )
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
	$str .= "$_\n" for ( @callStack[ reverse( 1 .. $#callStack ) ] );
	printLog($str);
}

=cut


=head2 C<logHash>

Debugging function for dumping the contents of a hash to the log file in a nice
readable format.

=cut

sub logHash
{
	my ($hash) = @_;
	my $str = "$hash\n";

	foreach ( keys %$hash )
	{
		$str .= "$_ = $$hash{$_}\n";
	}

	printLog($str);
}

=head2 deprecate 

=cut

sub deprecate {

    shift;
    my $message = shift;
    $message ||= '';
    my ( $file, $line, $sub ) = ( caller(1) )[1,2,3];
    carp $message . "Deprecated function $sub called at $file line $line ";

}

#############################################################################
# end of package
#############################################################################

1;
