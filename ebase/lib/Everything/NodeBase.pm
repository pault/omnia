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
use Everything::NodeBase::Workspace;

use base 'Class::Accessor';
__PACKAGE__->follow_best_practice;
__PACKAGE__->mk_accessors(qw/storage/);

use Scalar::Util 'reftype';

BEGIN
{
	my @methlist = qw(
	getDatabaseHandle sqlDelete sqlSelect sqlSelectJoined getFieldsHash
	sqlSelectMany sqlSelectHashref sqlUpdate sqlInsert _quoteData sqlExecute
	getNodeByIdNew getNodeByName constructNode selectNodeWhere getNodeCursor
	countNodeMatches getAllTypes dropNodeTable quote genWhereString lastValue
       now createGroupTable fetchrow timediff getNodetypeTables createNodeTable addFieldToTable
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

	( my $file = $storage_class ) =~ s/::/\//g;
	$file .= '.pm';
	require $file;

	$this->{storage}  = $storage_class->new(
		nb    => $this,
		cache => $this->{cache}
	);

	$this->{storage}->databaseConnect( $dbname, $host, $user, $pass );
	$this->{nodetypeModules} = $this->buildNodetypeModules();

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
sole parameter is 0, then the workspace is deleted.  Note that this will
re-bless the current object, if the user is in a workspace.

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

	# XXX - ugly workaround; fix soon
	bless $this, 'Everything::NodeBase::Workspace';

	$this->joinWorkspace( $WORKSPACE );
}

=head2 C<buildNodetypeModules>

Perl 5.6 throws errors if we test "can" on a non-existing module.  This
function builds a hashref with keys to all of the modules that exist in the
Everything::Node:: dir This also casts "use" on the modules, loading them into
memory

=cut

sub buildNodetypeModules
{
	my $self = shift;

	my %modules;

	for my $nodetype ( $self->{storage}->fetch_all_nodetype_names( 'ORDER BY node_id' ) )
	{
	    my $module = "Everything::Node::$nodetype";
	    if ($self->loadNodetypeModule( $module ) ){
		$modules{ $module } = 1;

	    } else {
		my $module = "Everything::Node::$nodetype"; 
		my $typenode = $self->getNode($nodetype, 'nodetype');
		unless ($typenode) {
		    warn "No such nodetype $nodetype.";
		    next;
		}
		my $baseclass_id = $typenode->{extends_nodetype};
		my $baseclass = $self->getType($baseclass_id);

		eval qq|package $module;
                        use base 'Everything::Node::$$baseclass{title}';
                |;
		if ($@) {
		    warn "Error loading $nodetype as $module, $@";
		} else {
		    $modules{ $module } = 1;
		}
	    }

	}
	$self->make_node_accessors(\%modules);
	$self->load_nodemethods(\%modules);
	return \%modules;
}

sub make_node_accessors {
    my ( $self, $modules ) = @_;
    foreach (keys %$modules) {
	/::(\w+)$/;
	my $type_name = $1;
	my $nodetype_node = $self->getNode( $type_name, 'nodetype' );

	my $dbtable;
	if ($type_name eq 'node' ) {
	    $dbtable = 'node';
	    require Everything::Node::node;
	} else {
	    $dbtable = $nodetype_node->{sqltable};
	}
	next unless $dbtable;
	my @tables = split /,/, $dbtable;
	my @fields;
	push @fields, $self->getFields( $_ ) foreach @tables;
	$_->mk_accessors( @fields );
    }


}

sub load_nodemethods {

    my ($self, $modules) = @_;

    foreach my $fullname (keys %$modules) {

	my ($name) = $fullname =~ /::(\w+)$/;
	my $nodetype_node = $self->getType($name);

	my $methods = $self->getNodeWhere(
					  {
					   'supports_nodetype' => $nodetype_node->{node_id}
					  },
					  'nodemethod'
					 );
	next unless $methods;
	foreach my $method (@$methods) {

	    my $code = "package $fullname;\n use SUPER;" . "\n\n sub " .  $method->{title} . " {\n $$method{code} \n}";
	    eval $code;
	    warn "Having trouble putting nodemethod $$method{title} into symbol table, $@" if $@;
	}
    }
    
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

	for my $path (@INC)
	{
		next unless -e File::Spec->canonpath(
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

=head2 duplicate_title

Checks whether a node not yet stored in the nodebase, duplicates a
title and whether that nodetype restricts duplicate titles.

It takes one argument which is the node object to be inserted.

Returns 'true' on success. 'False' if a node may not be inserted.

=cut

sub duplicate_title {

    my ( $this, $node ) = @_;

    return 1 unless $node->get_type->{restrictdupes};

    # Check to see if we already have a node of this title.
    my $id = $node->get_type->getId();

    my $DUPELIST =
      $this
	->sqlSelect( 'count(*)', 'node', 'title = ? AND type_nodetype = ?',
		     '', [ $node->get_title, $id ] );

    # A node of this name already exists and restrict dupes is
    # on for this nodetype.  Don't do anything
    return 0 if $DUPELIST;

    return 1;
}

=head2 store_new_node

Stores/saves the node in nodebase for later retrieval.

Takes a blessed node object as its first argument, and a node user object as its second.

Returns the node identifier on success false otherwise.

=cut

sub store_new_node {

        my ( $this, $node, $user ) = @_;

	my $node_id = $node->get_node_id;

	my ( $user_id, %tableData );

	$user_id = $user->getId() if eval { $user->isa( 'Everything::Node' ) };

	$user_id ||= $user;

	return 0 unless $node->hasAccess( $user, 'c' ) and $node->restrictTitle();

	# If the node_id greater than zero, this has already been inserted and
	# we are not forcing it.
	return $node_id if $node_id > 0;

	return 0 unless $this->duplicate_title( $node );

	$node_id = $this->get_storage->insert_node( $node, $user_id );

	# Now that it is inserted, we need to force get it.  This way we
	# get all the fields.  We then clear the $this hash and copy in
	# the info from the newly inserted node.  This way, the user of
	# the API just calls $NODE->insert() and their node gets filled
	# out for them.  Woo hoo!
	my $newNode = $this->getNode( $node_id, 'force' );

	undef %$node;
	@$node{ keys %$newNode } = values %$newNode;
	$$node{node_id}= $node_id;

	# Cache this node since it has been inserted.  This way the cached
	# version will be the same as the node in the db.
	$node->cache();

	return $node_id;
}

=head2 update_stored_node

Updates a node that has been stored in the nodebase database.

It takes three arguments:

=over

=item node

The node object that is being updated

=item user

The user object against which permissions are checked

=item options

A hash reference of options.  Currently the allowed options are:

=over

=item NOMODIFIED

If set to true then does not update the 'modified' attribute.

=back

=back

=cut
sub update_stored_node {

        my ( $this, $node, $USER, $options ) = @_;

	my $nomodified = $$options{ NOMODIFIED };

	return 0 unless $node->hasAccess( $USER, 'w' );

	if (    exists $this->{workspace}
		and $node->canWorkspace()
		and $this->{workspace}{nodes}{ $node->{node_id} } ne 'commit' )
	{
		my $id = $node->updateWorkspaced($USER);
		return $id if $id;
	}

	# Cache this node since it has been updated.  This way the cached
	# version will be the same as the node in the db.
	$this->{cache}->incrementGlobalVersion($node);
	$node->cache();
	$node->{modified} = $this->sqlSelect( $this->now() )
		unless $nomodified;

	# We extract the values from the node for each table that it joins
	# on and update each table individually.
	my $tableArray = $node->{type}->getTableArray(1);

	foreach my $table (@$tableArray)
	{
		my %VALUES;

		my @fields = $this->getFields($table);

		foreach my $field (@fields)
		{
			$VALUES{$field} = $node->{$field} if exists $node->{$field};
		}

		$this->{storage}->update_or_insert( {
			table => $table,
			data => \%VALUES,
			where => "${table}_id = ?",
			bound => [ $node->{node_id} ],
			node_id => $node->getId
                }
		);
	}

	return $node->{node_id};
}

=head2 delete_stored_node

Deletes a persistent node and all references to it in the nodebase.

This method takes two arguments:

=over

=item node

The node to be delete

=item user

The user node object that is attempting to carry out the deletion

=back

=cut

sub delete_stored_node {

        my ( $this, $node, $USER ) = @_;
	my $result = 0;

	$this->getRef($USER) unless $USER eq '-1';

	return 0 unless $node->hasAccess( $USER, 'd' );

	my $id = $node->getId();

	# Remove all links that go from or to this node that we are deleting
	$this->sqlDelete( 'links', 'to_node=? OR from_node=?', [ $id, $id ] );

	# Remove all revisions of this node
	$this->sqlDelete( 'revision', 'node_id = ?', [ $node->{node_id} ] );

	# Now lets remove this node from all nodegroups that contain it.  This
	# is a bit more complicated than removing the links as nodegroup types
	# can specify their own group table if desired.  This needs to find
	# all used group tables and check for the existance of this node in
	# any of those groups.
	foreach my $TYPE ( $this->getAllTypes() )
	{
		my $table = $TYPE->isGroupType();
		next unless $table;

		# This nodetype is a group.  See if this node exists in any of its
		# tables.
		my $csr =
			$this
			->sqlSelectMany( "${table}_id", $table, 'node_id = ?', undef,
			[ $node->{node_id} ] );

		if ($csr)
		{
			my %GROUPS;
			while ( my $group = $csr->fetchrow() )
			{

				# For each entry, mark each group that this node belongs
				# to.  A node may be in a the same group more than once.
				# This prevents us from working with the same group node
				# more than once.
				$GROUPS{$group} = 1;
			}
			$csr->finish();

			# Now that we have a list of which group nodes that contains
			# this node, we are free to delete all rows from the node
			# table that reference this node.
			$this
				->sqlDelete( $table, 'node_id = ?', [ $node->{node_id} ] );

			foreach ( keys %GROUPS )
			{

				# Lastly, for each group that contains this node in its
				# group, we need to increment its global version such
				# that it will get reloaded from the database the next
				# time it is used.
				my $GROUP = $this->getNode($_);
				$this->{cache}->incrementGlobalVersion($GROUP);
			}
		}
	}

	# Actually remove this node from the database.
	my $tableArray = $node->{type}->getTableArray(1);
	foreach my $table (@$tableArray)
	{
		$result += $this->sqlDelete( $table, "${table}_id = ?", [$id] );
	}

	# Now we can remove the nuked node from the cache so we don't get
	# stale data.
	$this->{cache}->incrementGlobalVersion($node);
	$this->{cache}->removeNode($node);

	# Clear out the node id so that we can tell this is a "non-existant" node.
	$node->{node_id} = 0;

	return $result;

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
		return $nodeArray->[0] if @$nodeArray;
		return;
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
			};

			# We do not want to cache dummy nodes
			$cache = "nocache";
		}
	}

	return unless $NODE;

	return Everything::Node->new( $NODE, $this, $cache );
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

	unless ( exists $this->{nodezero} )
	{
		$this->{nodezero} = $this->getNode( '/', 'location', 'create force' );

		$this->{nodezero}{node_id}     = 0;
		$this->{nodezero}{guestaccess} = "-----";
		$this->{nodezero}{otheraccess} = "-----";
		$this->{nodezero}{groupaccess} = "-----";
		$this->{nodezero}{author_user} = $this->getNode( 'root', 'user' );
	}

	return $this->{nodezero};
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

=head2 C<getRef>

This makes sure that we have an array of node hashes, not node ids.

Returns the node hash of the first element passed in.

=cut

sub getRef
{
	my $this = shift;

	for my $ref (@_)
	{
		next if eval { $ref->isa( 'Everything::Node' ) };
		$ref = $this->getNode($ref) if defined $ref;
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


=head2 C<search_node_title>

Applies a search algorithm to words passed as arguments

=over 4

=item *

Takes an array ref of words to search on


=item *

And an array ref of nodetypes to search on


=back

Returns an array of hash refs.

=cut

sub search_node_name {

    my ( $self, $words, $types ) = @_;
    my $match = '';

    $types = [$types] if defined $types and $types and ref($types) eq "SCALAR";

    my $typestr = '';
    if ( ref($types) eq 'ARRAY' and @$types ) {
        my $t = shift @$types;
        $typestr .= "AND (type_nodetype = " . $self->getId($t);
        foreach (@$types) {
            $typestr .= " OR type_nodetype = " . $self->getId($_);
        }

        $typestr .= ')';
    }

    $match = '%' . join( '%', @$words ) . '%';
    my $cursor =
      $self->{storage}
      ->sqlSelectMany( "*", "node", "title like ? $typestr", undef, [$match] );

    return unless $cursor;

    my @ret;
    while ( my $m = $cursor->fetchrow_hashref ) {
        push @ret, $m;
    }

    return \@ret;

}


=head2 C<retrieve_links>

Retrieves 'links' from the database.  It takes one argument which is a
hash ref.  This hash ref provides the search criteria to return
links. It may have the following keys:

=over 4

=item from_node

The node being linked from


=item to_node

The node being linked to

=item linktype

The type of link.

=back

Returns an array of hash refs.

=cut

sub retrieve_links {

    my ( $self, $args ) = @_;

    my @column_names = keys %$args;
    my $where = join ' AND ', map "$_ = ?", @column_names;

    my $cursor = $self->sqlSelectMany( "from_node, to_node, linktype, hits, food", 'links', $where, undef, [ @$args{ @column_names } ] ); 

    my @results = ();

    while (my $link = $cursor->fetchrow_hashref) {
	push @results, $link;
    }

    return \@results;
}


=head2 C<retrieve_nodes_linked>

Retrieves 'links' from the database.  It takes two compulsory
arguments and a third optional one:

=over 4

=item direction

The first argument must be the word 'to' or the word 'from' indicating
whether we are searching for nodes linking to or nodes linking from.

=item node

This is a node being linked to or from

=item arg_hash

This argument is optional. It must be a hashref containing arguments
that are passed directly to C<retrieve_links>.

=back

Returns an array ref of node objects.

=cut

sub retrieve_nodes_linked {
    my ( $self, $direction, $node, $args ) = @_;

    $args ||= {};
    $$args{ $direction . '_node' } = $node->get_node_id;
    my $links = $self->retrieve_links( $args );

    my @nodes = ();
    my $wanted_direction = $direction eq 'to' ? 'from_node' : 'to_node';
    foreach ( @$links ) {
	my $node = $self->getNode( $_->{ $wanted_direction } );
	push @nodes, $node;
    }

    return \@nodes;
}

=head2 C<total_links>

Counts the number of 'links' in the database.  It takes one argument which is a
hash ref.  This hash ref provides the search criteria to return
links. It may have the following keys:

=over 4

=item from_node

The node being linked from. This may be a node object or a node id.


=item to_node

The node being linked to. This may be a node object or a node id.

=item linktype

The type of link.

=back

Returns an integer. May possibly return '0 but true', so you should
use a numeric test if you want to test for the absence of links.

=cut

sub total_links {
    my ( $self, $args ) = @_;

    foreach (qw/from_node to_node/) {
	    $$args{ $_ } = $$args{ $_ }->get_node_id if ref $$args{ $_ };
    }

    my @column_names = keys %$args;
    my $where = join ' AND ', map "$_ = ?", @column_names;

    $self->sqlSelect( 'count(1)', 'links', $where, undef,  [ @$args{ @column_names } ] ); 

}


=head2 C<insert_link>

Inserts a link into the database.  Takes one argument, a hash ref
whose keys are the attribute names of the new link. The keys may be:

=over 4

=item from_node

The node being linked from. This may be a node object or a node id.


=item to_node

The node being linked to. This may be a node object or a node id.

=item linktype

The type of link.

=back

Returns true on success.

=cut

sub insert_link {

    my ( $self, $args ) = @_;

    foreach (qw/from_node to_node/) {
	    $$args{ $_ } = $$args{ $_ }->get_node_id if ref $$args{ $_ };
    }

    $self->sqlInsert( 'links', $args );
}


=head2 C<delete_links>

Deletes one or several links from the database.  It takes one argument
which is a hash ref.  This hash ref provides the search criteria
(i.e. the 'where' clause) that governs what link(s) are deleted. The
hash ref may have the following keys:

=over 4

=item from_node

The node being linked from


=item to_node

The node being linked to

=item linktype

The type of link.

=back

Returns true on success.

=cut

sub delete_links {

    my ( $self, $args ) = @_;

    foreach (qw/from_node to_node/) {
	    $$args{ $_ } = $$args{ $_ }->get_node_id if ref $$args{ $_ };
    }

    my @column_names = keys %$args;
    my $where = join ' AND ', map "$_ = ?", @column_names;

    $self->sqlDelete( 'links', $where,  [ @$args{ @column_names } ]  );
}



1;
