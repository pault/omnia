=head1 Everything::NodeBase

Wrapper for the Everything database and cache.  

Copyright 1999 - 2006 Everything Development Inc.

=cut

package Everything::NodeBase;

use strict;
use warnings;

use File::Spec;
use Everything ();
use Everything::DB;
use Everything::Node;
use Everything::NodeCache;
use Scalar::Util 'reftype';

BEGIN
{
	my @methlist = qw(
	buildNodetypeModules getDatabaseHandle sqlDelete sqlSelect sqlSelectJoined
	sqlSelectMany sqlSelectHashref sqlUpdate sqlInsert _quoteData sqlExecute
	getNodeByIdNew getNodeByName constructNode selectNodeWhere getNodeCursor
	countNodeMatches getAllTypes dropNodeTable quote genWhereString
	);

	for my $method (@methlist)
	{
		my $sub = sub
		{
			local *__ANON__ = $method;
			my $self = shift;
			$self->{storage}->$method( @_ );
		};

		no strict 'refs';
		*{ $method } = $sub;
	}
}

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
	my ( $class, $db, $staticNodetypes, $storage ) = @_;

	my ( $dbname, $user, $pass, $host ) = split /:/, $db;
	$user ||= 'root';
	$pass ||= '';
	$host ||= 'localhost';

	my $this                 = bless {}, $class;

	$this->{cache}           = Everything::NodeCache->new( $this, 300 );
	$this->{dbname}          = $dbname;
	$this->{staticNodetypes} = $staticNodetypes ? 1 : 0;

	my $storage_class = 'Everything::DB::' . $storage;
	$this->{storage}  = $storage_class->new( cache => $this->{cache} );

	$this->{storage}->databaseConnect( $dbname, $host, $user, $pass );
	$this->{nodetypeModules} = $this->{storage}->buildNodetypeModules();

	if ( $this->getType('setting') )
	{
		my $CACHE     = $this->getNode( 'cache settings', 'setting' );
		my $cacheSize = 300;

		# Get the settings from the system
		if ( defined $CACHE && $CACHE->isa( 'Everything::Node' ) )
		{
			my $vars = $CACHE->getVars();
			$cacheSize = $vars->{maxSize} if exists $vars->{maxSize};
		}

		$this->{cache}->setCacheSize($cacheSize);
	}

	return $this;
}

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

		$val1 = $val1->{node_id} if eval { $val1->isa( 'Everything::Node' ) };
		$val2 = $val2->{node_id} if eval { $val2->isa( 'Everything::Node' ) };

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

sub getNodeById
{
	my ( $this, $node_id, $selectop ) = @_;

	return $this->getNode( $node_id, $selectop );
}

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
	return $node if eval { $node->isa( 'Everything::Node' ) };

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
		and ( reftype( $selectNodeWhere ) || '' ) eq 'ARRAY';

	my @nodelist;

	foreach my $node ( @{$selectNodeWhere} )
	{
		my $NODE = $this->getNode($node);
		push @nodelist, $NODE if $NODE;
	}

	return \@nodelist;
}

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
	return $idOrName if eval { $idOrName->isa( 'Everything::Node' ) };

	return $this->getNode( $idOrName, 1 ) if $idOrName =~ /\D/;
	return $this->getNode($idOrName) if $idOrName > 0;
	return;
}

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

=head1 Private methods

These methods are private.  Don't call them.  They won't call you.

=head2 C<getNodetypeTables>

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

=head2 C<getRef>

This makes sure that we have an array of node hashes, not node ids.

Returns the node hash of the first element passed in.

=cut

sub getRef
{
	my $this = shift;
	local $_;

	for (@_)
	{
		next if eval { $_->isa( 'Everything::Node' ) };
		$_ = $this->getNode($_) if defined $_;
	}

	return $_[0];
}

=head2 C<getId>

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
	return $node->{node_id} if eval { $node->isa( 'Everything::Node' ) };
	return $node if $node =~ /^-?\d+$/;
	return;
}

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

1;
