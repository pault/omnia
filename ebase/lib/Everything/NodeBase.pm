=head1 Everything::NodeBase

Wrapper for the Everything database and cache.  

Copyright 1999 - 2006 Everything Development Inc.

=cut

package Everything::NodeBase;

use strict;
use warnings;
use Carp qw/cluck carp/;
use Everything::Node::nodetype;
use Everything::Node::node;
use Everything::Node;

use File::Spec;
use Everything ();
use Everything::DB;
use Everything::NodeBase::Workspace;
use Everything::NodeAccess;

use Moose;

with 'Everything::NodeBase::NodetypeRegister';

use MooseX::FollowPBP;


has storage => ( is => 'rw' );
has dbname => ( is => 'rw' );
has staticNodetypes => ( is => 'rw' );

use Scalar::Util 'reftype', 'blessed', 'looks_like_number';

BEGIN
{
	my @methlist = qw(
	getDatabaseHandle sqlDelete sqlSelect sqlSelectJoined getFieldsHash
	sqlSelectMany sqlSelectHashref sqlUpdate sqlInsert _quoteData sqlExecute
	getNodeByIdNew getNodeByName constructNode selectNodeWhere getNodeCursor
	countNodeMatches dropNodeTable quote genWhereString lastValue
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

sub BUILDARGS
{
	my ( $class, $db, $staticNodetypes, $storage ) = @_;

	my ( $dbname, $user, $pass, $host, $port ) = split /:/, $db;
	$user ||= 'root';
	$pass ||= '';
	$host ||= 'localhost';

	$staticNodetypes = $staticNodetypes ? 1 : 0;

	my $storage_class = 'Everything::DB::' . $storage;

	( my $file = $storage_class ) =~ s/::/\//g;
	$file .= '.pm';
	require $file;

	my $storage_object  = $storage_class->new(
		dbname => $dbname,
	);

	$storage_object->databaseConnect( $dbname, $host, $user, $pass, $port );

	return +{ storage => $storage_object, dbname => $dbname, staticNodetypes=> $staticNodetypes }
    
    }

sub BUILD {

        my $this = shift;

	$this->buildNodetypeModules();
}


=head2 update_workspaced_node

This method is called by $this-E<gt>update() to handle the insertion of the
workspace into the revision table.  This also exists so that it could be
overloaded by tricky nodetypes.

=over 4

=item * $node

the node being updated

=item * $USER

the user who is updating

=back

Returns the node_id of the node, if successful otherwise null.

=cut

sub update_workspaced_node {
    my ( $this, $node, $USER ) = @_;

    return unless $node->canWorkspace();

    my $revision = $this->log_node_revision($node, $USER);
    $this->{workspace}{nodes}{ $node->{node_id} } = $revision;
    $this->{workspace}->setVars( $this->{workspace}{nodes} );
    $this->{workspace}->update($node, $USER);

    return $node->{node_id};
}

=head2 log_node_revision

A node is about to be updated.  Load its old settings from the database,
convert to XML, and save in the "revision" table The revision can be
re-instated with undo()  

=over 4

=item * $USER

same as update, the user who is making this revision

=back

Returns 0 if failed for any reason, otherwise the latest revision_id.

=cut

sub log_node_revision {

    my ( $this, $node, $USER ) = @_;
    return 0 unless $node->hasAccess( $USER, 'w' );

    my $workspace;
    $workspace = $this->{workspace}{node_id}
      if ( exists $this->{workspace} && $node->canWorkspace() );
    $workspace ||= 0;

    my $node_class = blessed $node;

    my $maxrevisions = $this->nodetype( $node_class )->{maxrevisions};
    $maxrevisions = $this->nodetype( $node_class )->{derived_maxrevisions} if $maxrevisions == -1;
    $maxrevisions ||= 0;

    # We should never revise a node, even if we are in a workspace.
    return 0 unless $maxrevisions;

    # we are updating the node -- remove any "redo" revisions

    if ( not $workspace ) {
        $this->get_storage->sqlDelete(
            'revision',
            'node_id = ? and revision_id < 0 and inside_workspace = ?',
            [ $node->{node_id}, $workspace ]
        );
    }
    else {
        if ( exists $this->{workspace}{nodes}{ $node->getId } ) {
            my $rev = $this->{workspace}{nodes}{ $node->getId };
            $this->get_storage->sqlDelete(
                'revision',
                'node_id = ? and revision_id > ? and inside_workspace = ?',
                [ $node->getId, $rev, $workspace ]
            );
        }
    }

    my $data =
      $workspace
      ? Everything::XML::Node->new( node => $node, nodebase => $this )
      ->toXML
      : Everything::XML::Node->new(
        node     => $this->getNode( $node->getId, 'force' ),
        nodebase => $this
      )->toXML();

    my $rev_id =
      $this->get_storage->sqlSelect( 'max(revision_id)+1', 'revision',
        'node_id = ? and inside_workspace = ?',
        '', [ $node->{node_id}, $workspace ] )
      || 1;

    # insert the node as a revision
    $this->get_storage->sqlInsert(
        'revision',
        {
            xml              => $data,
            node_id          => $node->getId,
            revision_id      => $rev_id,
            inside_workspace => $workspace,
        }
    );

    # remove the oldest revision, if it's greater than the set maxrevisions
    # only if we're not in a workspace

    my ( $numrevisions, $oldest, $newest ) = @{
        $this->get_storage->sqlSelect(
            'count(*), min(revision_id), max(revision_id)',
            'revision',
            'inside_workspace = ? and node_id = ?',
            '',
            [ $workspace, $node->{node_id} ]
        )
      };

    if ( not $workspace and $maxrevisions < $numrevisions ) {
        $this->get_storage->sqlDelete(
            'revision',
            'node_id = ? and revision_id = ? and inside_workspace = ?',
            [ $node->{node_id}, $oldest, $workspace ]
        );
    }

    return $newest;

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

sub buildNodetypeModules {
    my $self = shift;

    for my $nodetype (
        $self->get_storage->fetch_all_nodetype_names('ORDER BY node_id') )
    {
	next if $self->nodetype( 'Everything::Node::'.$nodetype);
	my $module = $self->setup_module( $nodetype );

     }
    $self->load_nodemethods();

    return $self->nodetype_modules;
}

sub setup_module {

    my ( $self, $nodetype ) = @_;
    my $storage = $self->get_storage;
    my $module        = "Everything::Node::$nodetype";

    ## returns an unblessed hash ref
    my $typenode_data =
      $self->get_storage->nodetype_data_by_name( $nodetype );

   unless ($typenode_data) {
	warn "No such nodetype $nodetype.";
	return;
    }

    my $baseclass_id = $typenode_data->{extends_nodetype};
    my $baseclass;

    $baseclass  = $storage->nodetype_data_by_id($baseclass_id); # returns unblessed hash ref


    my $baseclass_title;
    if ( $baseclass ) {
	$baseclass_title = $baseclass->{ title };
	$self->setup_module( $baseclass_title );# unless $self->nodetype( "Everything::Node::$baseclass_title" ); # recurse


    }

    if ( $self->loadNodetypeModule($module) ) {
	    my $type_node = $self->set_module_nodetype( $module );
	    $module->import;
	    $self->register_type_module( $module => $type_node );
	    return $module;

        }
        else {
	    return $self->create_module( $module, $typenode_data, $baseclass_title );
	    
        }
    return;
}

=head2 create_module

Creates a 'package' of a nodetype class by inserting into the symbol table. It takes the following arguments:

=over

=item module

the full name of the module being created - a string

=item nodetype data

a hashref of the data that would be used to create the nodetype

=item baseclass_name

The name, i.e. title of the node type of the base nodetype

=item modules_loaded

A hashref of all the modules loaded.  On success modifies this in place.

=back

Returns the module name created on success false otherwise.

=cut

sub create_module {

    my( $self, $module, $typenode_data, $baseclass_title, $modules_loaded ) = @_;

	    if ( not $baseclass_title ) {
		Carp::cluck "Can't load a virtual node $$typenode_data{ title }, because there is no baseclass.";
		return;
	    }

            my $metaclass =
              Moose::Meta::Class->create( $module,
                superclasses => ["Everything::Node::$baseclass_title"] );

	    my $type_node = $self->set_module_nodetype( $module );
            $self->make_node_accessor( $metaclass, $typenode_data );
#	    $module->load_class_data( $self );
    $self->register_type_module(  $module => $type_node );
    return $module;
}

sub set_module_nodetype {

    my ( $self, $package ) = @_;
    my ($name) = $package =~ /::(\w+)$/;

    my $data;
    my $typenode;

    ## call the function in THIS package and bypass the cache.  Yes
    ## this is a hack, but it works. It is necessary, because
    ## 'buildNodetypeModules is called BEFORE the cache is ready,
    ## which means direct calls to getNode and related methods
    ## break. There might be better fixes than this which are more
    ## transparent to any sub-classers.

    $typenode = &retrieve_node_using_name_type ( $self, $name, 'nodetype' );

    return $typenode;

}



sub make_node_accessor {

    my ( $self, $metaclass, $typenode_data ) = @_;

    my $tables = $typenode_data->{sqltable};

    return unless $tables;
    foreach my $table ( split /,/, $tables ) {
	foreach my $field ( $self->getFields( $table ) ) {
	    $metaclass->add_attribute( $field, 'reader' => "get_$field", 'writer' => "set_$field");
	}
    }
}

sub load_nodemethods {

    my ($self, $modules) = @_;

    foreach my $fullname (keys %$modules) {

	my ($name) = $fullname =~ /::(\w+)$/;
	my $nodetype_node = $self->getType($name);
	my $methods = $self->getNodeWhere(
					  {
					   'supports_nodetype' => $nodetype_node->getId
					  },
					  'nodemethod'
					 );
	next unless $methods;

	foreach my $method (@$methods) {

	    my $meta_class = $fullname->meta;

	    my $code = $method->get_code;

	    ## XXX: this needs to be moved out so all eval occurs in
	    ## same place - say in Runnable.pm

	    ## no critic
	    my $code_ref = eval 'sub { ' . $code . ' }';
	    ## use critic

	    warn "Having trouble putting nodemethod $$method{title} into symbol table, $@" if $@;
	    $meta_class->add_method ( $method->get_title , $code_ref );
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

	$this->purge_register;
	$this->buildNodetypeModules();

	return;
}

sub loadNodetypeModule
{
	my ( $self, $modname ) = @_;
	( my $modpath = $modname . '.pm' ) =~ s!::!/!g;

	if ( exists $INC{$modpath} ) {
		    return 1;

	}

	for my $path (@INC)
	{
		next unless -e File::Spec->canonpath(
			File::Spec->catfile( $path, $modpath ) );

		if ( eval { require $modpath } ) {
		    last;
		}
	}

	Everything::logErrors( '', "Using '$modname' gave errors: '$@'" )
		if $@ and $@ !~ /Can't locate/;

	return exists $INC{$modpath};
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
	## XXXX: if types know about storage should be here

	if ( $this->storage_settings( $node )->{restrictdupes} )
	{
		# Check to see if we already have a node of this title.
		my $id = $node->get_type_nodetype;

		my $DUPELIST =
			$this
			->sqlSelect( 'count(*)', 'node', 'title = ? AND type_nodetype = ?',
			'', [ $node->get_title, $id ] );

		# A node of this name already exists and restrict dupes is
		# on for this nodetype.  Don't do anything
		return 0 if $DUPELIST;
	}

	# Clean up some data;

	# Assign the author_user to whoever is trying to insert this.
	# Unless, an author has already been specified.
	$node->{author_user} ||= $user_id;

	$node_id = $node->type->insert_node( $node );

	# Now that it is inserted, we need to force get it.  This way we
	# get all the fields.  We then clear the $this hash and copy in
	# the info from the newly inserted node.  This way, the user of
	# the API just calls $NODE->insert() and their node gets filled
	# out for them.  Woo hoo!

	$this->rebuildNodetypeModules if $node->isa( 'Everything::Node::nodetype' );

	my $newNode = $this->getNode( $node_id, 'force' );
	undef %$node;
	@$node{ keys %$newNode } = values %$newNode;
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

	$options ||= {};

	my $nomodified = $$options{ NOMODIFIED };

	return 0 unless $node->hasAccess( $USER, 'w' );

	if (    exists $this->{workspace}
		and $node->canWorkspace()
		and $this->{workspace}{nodes}{ $node->{node_id} } ne 'commit' )
	{
		my $id = $node->updateWorkspaced($USER);
		return $id if $id;
	}

	$node->{modified} = $this->sqlSelect( $this->now() )
		unless $nomodified;

	my $id = $node->type->update_node( $node );

	if ( blessed( $node ) eq 'Everything::Node::nodetype' ) {
	    $this->rebuildNodetypeModules;

	}
	return $id;

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

	$this->remove_from_groups( $node );

	# Actually remove this node from the database.

	$result = $node->type->delete_node( $node );
#	$result = $this->get_storage->purge_node_data( $node );

	# Clear out the node id so that we can tell this is a "non-existant" node.
	$node->{node_id} = 0;

	return $result;

}

sub remove_from_groups {

    my ( $this, $node ) = @_;
	foreach my $TYPE ( $this->getAllTypes() )
	{
	    next unless $TYPE->isa( 'Everything::Node::nodegroup' );

	    my $table = $TYPE->get_grouptable;
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


}



sub retrieve_node_using_id {

    my ( $this, $node_id, $ext ) = @_;

    # first get basic data and Nodetype

    my $cursor = $this->getNodeCursor( "*", { node_id => $node_id }, undef, undef, undef, undef, 1 );

    return unless $cursor;

    my $node_data = $cursor->fetchrow_hashref();
    $cursor->finish();

    return unless $node_data;

    my $type = $this->nodetype_for_node( { id => $node_data->{type_nodetype} } );

    return $type->node( { nodebase => $this, node_id => $node_id } );

}


sub retrieve_node_using_name_type {

    my ( $this, $name, $nodetype_title ) = @_;

    my $node_data;

    if ( $nodetype_title eq 'nodetype') {

	return $this->nodetype_for_node ( { title => $name } );

    } else {

	my $type = $this->nodetype_for_node( { title => $nodetype_title } );

	return $type->node( { nodebase => $this, title => $name } );

    }

    die "Can't get node by title and nodetype."

}

sub nodetype_for_node {
    my ( $this, $args ) = @_;

    my $type;

    if ( $args->{id} ) {

	$type = $this->nodetype_by_id( $args->{id} );

	# bootstrap getting nodetypes

	if ( ! $type ) {
	    my $data = $this->get_storage->nodetype_data_by_id( $args->{id} );
	    die "No nodetype data for id $$args{id}" unless $data;
	    $type = $this->make_node( $data, 'nodetype');
	}

    } elsif ( $args->{title} ) {
	  $type = $this->nodetype_by_title( $args->{title} );

	if ( ! $type ) {
	    my $data = $this->get_storage->nodetype_data_by_name( $args->{title} );
	    return unless $data;
	    $type = $this->make_node( $data, 'nodetype');
	}


    } else {
	die "Can't get nodetype.";
    }
    return $type;

}

sub make_node {
    my ( $self, $node_data, $nodetype_title ) = @_;

    my $class = "Everything::Node::" . $nodetype_title;

    my $node= $class->new( %$node_data, DB => $self, nodebase => $self, _type => $self->nodetype( $class ) );
    my $access = $self->make_access( $node );

    $node->set_access ( $access );
    return $node;
}

=head2 make_access

Returns an access object against which hasAccess can be called.

Takes a blessed node object as its argument.

=cut

sub make_access {
    my ( $self, $node ) = @_;

    my $storage = $self->get_storage;

    my $type_hierarchy = $self->get_storage->nodetype_hierarchy_by_id( $node->get_type_nodetype );

    my $default_accesses = $self->default_type_access( $type_hierarchy );

    my $default_permissions = $self->default_type_permissions( $type_hierarchy );

    my $usergroup = $self->default_type_usergroup( $type_hierarchy );
    my $access = Everything::NodeAccess->new( node => $node, nb => $self, default_accesses => $default_accesses, usergroup => $usergroup, default_permissions => $default_permissions );

    return $access;
}

=head2 default_type_usergroup

Takes an array ref of type data and returns the default usergroup.

=cut

sub default_type_usergroup {
    my ( $self, $hierarchy ) = @_;

    my $attribute = 'defaultgroup_usergroup';
    foreach my $type ( @$hierarchy ) {
	if ( ( not defined $$type{ $attribute } ) || ( $$type{ $attribute } == -1) ) {
	    next;
	}
	return $$type{ $attribute };
    }
}

=head2 default_type_permissions

Takes an array ref of default permissions as its argument and returns
a hashref of strings.

=cut

sub default_type_permissions {


   shift;
   my $type_hierarchy = shift;

   my %default_permissions = ();
    foreach my $usertype (qw/author group other guest/) {
	my $userperm = "default${usertype}_permission";

      TYPE:
	foreach my $type (@$type_hierarchy) {
	    if ( ( not defined $$type{ $userperm } ) || ( $$type{ $userperm } == -1) ) {
		next TYPE
	    }
	    $default_permissions{ $usertype } = $$type{ $userperm } ;
	    last TYPE
	}

    }

   return \%default_permissions;


}

=head2 default_type_access

Takes an array ref of default accesses as its argument and returns
a hashref of strings.

=cut

sub default_type_access {

   shift;
   my $type_hierarchy = shift;

   my %default_permissions = ();
    foreach my $usertype (qw/author group other guest/) {
	my $userperm = "default${usertype}access";
	my $index = $#$type_hierarchy;
	while ( $index > 0 ) {
	    my $perms = Everything::Security::inheritPermissions( $$type_hierarchy[$index-1]{$userperm},  $$type_hierarchy[$index]{$userperm} );

	    $$type_hierarchy[$index-1]{$userperm} = $perms;
	    $index--;
	}
	$default_permissions{ $usertype } = $$type_hierarchy[0]{$userperm};
    }

   return \%default_permissions;

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
nodetype node, or a nodetype id. If $node is a string title and $ext is not defined, undef will be returned.

If $node is an id, $ext is optional and can
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

	$ext2 ||= q{};

	if ( ref $node eq 'HASH' )
	{
		# This a "where" select
		my $nodeArray = $this->getNodeWhere( $node, $ext, $ext2, 1 ) || [];
		return $nodeArray->[0] if @$nodeArray;
		return;
	}
	elsif ( looks_like_number( $node ) )
	{
	    return $NODE = $this->retrieve_node_using_id( $node, $ext );
	}
	else
	{
	    my $type_name;
	    my $type_node;

	    if ( not $ext ) {
		return;
	    } elsif ( blessed $ext ) {
		$type_name = $ext->get_title;
		$type_node = $ext;
	    } elsif ( $ext =~ /^\d+$/ ) {
		$type_node = $this->getNode( $ext );
		$type_name = $type_node->get_title;
	    } else {
		$type_name = $ext;
		$type_node = $this->retrieve_node_using_name_type( $ext, 'nodetype' );
	    }

	    if (  $ext2 eq "create force"  )
	      {
		  return $this->create_dummy_node( $node, $type_name );
	      }

	    $NODE = $this->retrieve_node_using_name_type( $node, $type_name );

	    if ( (not defined $NODE) && ( $ext2 eq 'create') ) {
		$NODE = $this->create_dummy_node( $node, $type_name );

		return $NODE;

	    }

	    return $NODE;

	}
    }

sub create_dummy_node {
    my ( $this, $node, $type_name ) = @_;

    my $class     = "Everything::Node::$type_name";
    my $type_hash = $this->get_storage->nodetype_data_by_name($type_name);
    my $type_id   = $type_hash->{node_id};
    my $NODE;

    # We need to create a dummy node for possible insertion!
    # Give the dummy node pemssions to inherit everything
    my $data = {
        node_id       => -1,
        title         => $node,
        type_nodetype => $type_id,
        authoraccess  => 'iiii',
        groupaccess   => 'iiiii',
        otheraccess   => 'iiiii',
        guestaccess   => 'iiiii',
    };

    $NODE = $class->new( %$data, DB => $this, nodebase => $this, _type => $this->nodetype_by_id( $$data{type_nodetype} ) );
    $NODE->set_access( $this->make_access($NODE) );

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

	unless ( exists $this->{nodezero} )
	{
		$this->{nodezero} = $this->getNode( '/', 'node', 'create force' );

		$this->{nodezero}{node_id}     = 0;
		$this->{nodezero}{guestaccess} = "-----";
		$this->{nodezero}{otheraccess} = "-----";
		$this->{nodezero}{groupaccess} = "-----";
#		$this->{nodezero}{author_user} = $this->getNode( 'root', 'user' );
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
	my $WHERE = shift;
	my $TYPE = shift;
	my $node_type = $this->getNode( $TYPE, 'nodetype' );
	my $selectNodeWhere = $this->selectNodeWhere($WHERE, $node_type, @_);

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

	return $this->getNode( $idOrName, 'nodetype' ) if $idOrName =~ /\D/;

	return $this->getNode($idOrName) if $idOrName > 0;
	return;
}

=head2 C<getAllTypes>

This returns a list of the nodetypes in the system.  Useful
for knowing what nodetypes exist.

Returns an array of TYPE hashes of all the nodetypes in the system

=cut

sub getAllTypes
{
	my ($this) = @_;

	return @{ $this->getNodeWhere( {}, 'nodetype' ) || [] };

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

	## no critic
	my $perms = eval $PERM->{code};
	## use critic

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

=head2 storage_settings

Returns a hash reference of settings for the database.

Takes one argument, the node for whichsettings are required

=cut

sub storage_settings {

    my ( $self, $node ) = @_;

    my $hierarchy = $self->get_storage->nodetype_hierarchy_by_id( $node->get_type_nodetype );

    return $self->derive_storage_settings( $hierarchy );
}

sub derive_storage_settings {

    shift;
    my $hierarchy = shift;

    my $settings = {};

  SETTING:
    foreach my $setting ( qw/restrictdupes maxrevisions canworkspace/ ) {
      TYPE:
	foreach my $type ( @$hierarchy ) {
	    if ( ( not defined $$type{ $setting} ) || ( $$type{ $setting } == -1) ) {
		next TYPE
	    }
	    $$settings{ $setting } = $$type{ $setting };
	    last TYPE
	}
    }

    return $settings;
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


package Everything::NodetypeMetaData;

use Moose;
use MooseX::FollowPBP; 


has $_ => ( is => 'rw' )
  foreach qw( sqltable grouptable defaultgroup_usergroup
  defaultauthor_permission defaultgroup_permission
  defaultother_permission defaultguest_permission maxrevisions
  canworkspace restrictdupess
);

has defaultauthoraccess => ( is => 'rw' );
has  derived_defaultauthoraccess => ( is => 'rw' );

has $_ => ( is => 'rw' ) foreach  qw( defaultgroupaccess
  defaultotheraccess defaultguestaccess);
has $_ => ( is => 'rw' ) foreach map "derived_$_", qw( defaultgroupaccess
  defaultotheraccess defaultguestaccess);

has grouptable => ( is => 'rw' );
has derived_grouptable => ( is => 'rw', default => '' );

sub getId {

    1;
}

sub BUILD {

    my $self = shift;

    foreach (
        qw/ sqltable grouptable defaultauthoraccess defaultgroupaccess
        defaultotheraccess defaultguestaccess defaultgroup_usergroup
        defaultauthor_permission defaultgroup_permission
        defaultother_permission defaultguest_permission maxrevisions
        canworkspace
        /
      )
    {
      $self->{ "derived_$_"} = $self->{ $_ };

    }
}

## XXX: implement this as a Moose::Role
sub getTableArray {

    if ( $_[1] ) {
	return [ 'node', 'nodetype' ];
    }

    return ['nodetype']

};

sub get_title { 'node' };

sub default_data {

    my %data = ( title => 'default metadata' );

    $data{$_} = '' foreach qw{ sqltable grouptable  defaultgroup_usergroup
        defaultauthor_permission defaultgroup_permission
        defaultother_permission defaultguest_permission
        };

    $data{ $_ } = 0 foreach qw{maxrevisions canworkspace};
    $data{ defaultauthoraccess } = 'iiii';

    $data{$_} = 'iiiii' foreach qw {defaultgroupaccess
				    defaultotheraccess defaultguestaccess};
    return \%data;
}

1;
