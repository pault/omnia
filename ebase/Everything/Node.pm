package Everything::Node;

#############################################################################
#	Everything::Node
#		The basic class that implements the node object.
#
#	Notes
#		All methods in this package are intended to be methods that
#		pertain to nodes of *ALL* types.  If a method is needed by
#		a specific nodetype, it must be implemented in its own package,
#		or implemented as a nodemethod.  Methods in this package have
#		the performance benefit of not having to go through AUTOLOAD.
#		However, if the method is not used by all nodetypes, it must
#		go in its own package.
#
#	Copyright 2000 - 2003 Everything Development Inc.
#	Format: tabs = 4 spaces
#
#############################################################################

use strict;
use Everything ();
use Everything::Util;
use XML::DOM;


#############################################################################
#	Sub
#		new
#
#	Purpose
#		"Constructor" for the Node object.  This takes the given node hash
#		and just blesses it.  This should only be called by NodeBase when
#		it retrieves the nodes from the database to "objectify" them.
#
#	Parameters
#		$NODE - a reference to the node hash to bless, not an id or name!
#		$DB - when NodeBase.pm calls this, it passes a ref to itself
#			so that when we implement these methods, we can access
#			the basic sql functions.
#		$nocache - (optional) True if the new node should not be cached.
#			Preferably pass 'nocache', so that it's obvious what you are
#			doing.
#
sub new
{
	my ($className, $NODE, $DB, $nocache) = @_;

	return $NODE if(exists $$NODE{CREATED_NODE_OBJECT});

	# Mark this object as created so we don't go trying to create it again.
	$$NODE{CREATED_NODE_OBJECT} = 1;

	# Store the database handle;
	$$NODE{DB} = $DB;
	
	# We do not use the bless(obj, class) version of bless.  Why?  Nobody
	# is allowed to derive from Everything::Node because we implement our
	# own inheritance model.  Some or all of an object implementation may
	# be in the database.  Therefore, we are required to find the correct
	# implementation on our own.  Perl assumes all packages are located
	# in the file system somewhere (@INC).  In Everything, this may not
	# be true.  If we did the bless(obj, class) stuff, perl would try to
	# do stuff for us, and it would probably break.
	bless $NODE;

	$NODE->assignType();

	# Cache it.  If we don't do this, 'nodetype' will get stuck in an
	# infinite loop when creating itself.
	$NODE->cache() unless($nocache && $nocache ne "");
	
	# Let the nodetype do whatever it needs to make this node complete.
	$NODE->construct();

	return $NODE;
}


#############################################################################
#	Sub
#		DESTROY
#
#	Purpose
#		Gets called by perl when an object is about to be freed.  We
#		delete any pointers that we have to get rid of possible circular
#		references.
#
sub DESTROY
{
	my ($this) = @_;

	# Problem here is that the nodetype that is pointed to by $$this{type}
	# could get destructed first on shutdown which would make this
	# malfunction.  Disabling for now since this may not really be needed.
	#$this->destruct();

	# Remove any references that we may have.  Probably not necessary,
	# but will prevent the possibility any circular references.
	delete $$this{type};
	delete $$this{DB};
	delete $$this{SUPERtype};
	delete $$this{SUPERparams};
	delete $$this{SUPERfunc};
}


#############################################################################
#	Sub
#		getId
#
#	Purpose
#		Gets the numeric id of this object.
#
#	Returns
#		Duh
#
sub getId
{
	my ($this) = @_;
	return $$this{node_id};
}


#############################################################################
#	Sub
#		AUTOLOAD
#
#	Purpose
#		This allows us to call functions like $NODE->someFunc(), while
#		implementing them in either a .pm or a nodemethod node.  This is
#		the magic behind how Everything implements its method inheritance.
#		MAKE SURE YOU UNDERSTAND HOW THIS WORKS before changing anything in
#		here.  You could break the whole system if this is wrong.
#
#	Parameters
#		See the function you are trying to call for parameter info
#
#	Returns
#		Whatever the function you are calling returns
#
sub AUTOLOAD
{
	my $this = shift;

	# We just want the function name, not all the package info.
	my ($func) = $Everything::Node::AUTOLOAD =~ /::(\w+)$/;

	my $TYPE       = $this->{DB}->getType($$this{SUPERtype});
	my $origType   = $this->{SUPERtype};
	my $origFunc   = $this->{SUPERfunc};
	my $origParams = $this->{SUPERparams};
	my $result;

	if ((defined($this->{SUPERfunc})) && ($func ne $this->{SUPERfunc}))
	{
		# If the function being called is different from what we have
		# as a SUPERfunc, that means the implementation has called
		# another function on this same object.  We don't want to have
		# this call the function on the SUPERtype
		$TYPE = $this->{type};
	}
	else
	{
		$TYPE ||= $this->{type};
	}
	
	$this->{SUPERtype} = $TYPE->{node_id};
	$this->{SUPERfunc} = $func;

	# Make a copy of the parameters in case they modify the default array.
	$this->{SUPERparams} = [ @_ ];

	my $METHOD = $this->getNodeMethod($func, $TYPE);

	if (defined $METHOD)
	{
		my ($warn, $code, $N);
		my $error = '';

		# When we search for a method, on type X, we may find it on
		# one of its parent types.  So, we want to make sure we set
		# the current type appropriately otherwise we may end up
		# executing the same function 2 or more times (bad).
		$this->{SUPERtype} = $METHOD->{SUPERtype};

		local $SIG{__WARN__} = sub {
			$warn .= $_[0] unless $_[0] =~ /^Use of uninitialized value/;
		};

		if ($METHOD->{type} eq 'nodemethod')
		{
			# This a method that is in a node.  Eval it.
			unshift @_, $this;
			$N      = $this->{DB}->getNode($METHOD->{node});
			$code   = $N->{code};
			$code   =~ tr/\015//d;
			$result = eval($code);
			$error  = $@;
		}

		if ($error or $METHOD->{type} eq 'pm')
		{
			# We didn't find a method in node form.  Execute the default in
			# the corresponding .pm.
			$code    = $METHOD->{name} . "(\@_);";
			my $meth = $METHOD->{name};
			$result  = eval { $this->$meth( @_ ) };
		}

		Everything::logErrors($warn, $@, $code, $N) if $warn or $@;
	}
	else
	{
		# A function of the given name was not found for us!  Throw an error!
		die "Error!  No function '$func' for nodetype $this->{type}{title}.\n($TYPE->{node_id},$this->{title},$this->{node_id})";
	}

	# Set these back to what they were.  
	$this->{SUPERtype}   = $origType;
	$this->{SUPERfunc}   = $origFunc;
	$this->{SUPERparams} = $origParams;

	return $result;
}


#############################################################################
#	Sub
#		SUPER
#
#	Purpose
#		This implements the idea of calling a parent (inherited)
#		implementation from a overrided function.  This allows you to call
#		$this->SUPER();
#		from a function implementation and it will call the parent's
#		implementation of that function.  This is similar to the concept
#		in java.
#
#	Parameters
#		Any parameters that the parent implementation may take.  If nothing,
#		this will automatically pass the parameters that were passed to call
#		the overrided implemention of the function.
#
#	Returns
#		The result of calling the parent implementation
#
sub SUPER
{
	my $this = shift @_;
	my $TYPE = $$this{DB}->getType($$this{SUPERtype});
	my $PARENT = $$this{DB}->getType($$TYPE{extends_nodetype});
	
	if($PARENT)
	{
		my $origType = $$this{SUPERtype};
		my $origParams = $$this{SUPERparams};
		my $origFunc = $$this{SUPERfunc};
		my $result;
		
		$$this{SUPERtype} = $PARENT->getId();

		# If no parameters were passed, we will use the parameters passed
		# to the original call to this function.
		unless(@_)
		{
			my $params = $$this{SUPERparams};
			push @_, @$params;
		}
		
		# We use the object reference here to call the function.
		my $exec = "\$this->$$this{SUPERfunc}(\@_);";
		my $warn;
		
		local $SIG{__WARN__} = sub {
			$warn .= $_[0];
		};

		$result = eval($exec);

		local $SIG{__WARN__} = sub { };

		Everything::logErrors($warn, $@, $exec);

		$$this{SUPERtype} = $origType;
		$$this{SUPERparams} = $origParams;
		$$this{SUPERfunc} = $origFunc;

		return $result;
	}

	die "No SUPER for function $$this{SUPERfunc} for type $$TYPE{title}\n";
}


#############################################################################
#	Sub
#		getNodeMethod
#
#	Purpose
#		This is a utility function that finds the method of the given name
#		for the given type.  This searches for 'nodemethod' nodetypes and
#		the installed .pm implementations.  If it does not find one for that
#		type, it will run up the nodetype inheritence hierarchy until it
#		finds one, or determines that one does not exist.
#
#	Parameters
#		$func - the name of the method/function to find
#		$TYPE - the type of the node that is looking for this function
#
#	Returns
#		A hash structure that contains the method if found.  undef if no
#		method is found.  The hash returned has a 'type' field which is
#		either "nodemethod', or 'pm'.  Where 'nodemethod' indicates that
#		the function was found in a nodemethod node, and 'pm' indicates 
#		that it found the function implemented in a .pm file.  See the
#		code for the hash structures (grin).
#
sub getNodeMethod
{
	my ($this, $func, $TYPE) = @_;
	my $METHODTYPE;
	my $METHOD;
	my $RETURN;
	my $found = 0;
	my $cacheName = $$TYPE{title} . ":" . $func;

	# If we have it cached, return what we found
	$METHOD = $this->{DB}->{cache}->{methodCache}{$cacheName}
		if exists $this->{DB}->{cache}->{methodCache}{$cacheName};
	return $METHOD if $METHOD;
	
	$METHODTYPE = $$this{DB}->getType('nodemethod');

	if($METHODTYPE)
	{
		# First check to see if a nodemethod exists for this type.
		$METHOD = $$this{DB}->getNodeWhere( { 'title' => $func,
			'supports_nodetype' => $$TYPE{node_id} }, $METHODTYPE );
		$METHOD = shift @$METHOD;
	}

	if(not $METHOD)
	{
		# Ok, we don't have a nodemethod.  Check to see if we have
		# the function implemented in a .pm
		my $name = $$TYPE{title};
		$name =~ s/\W//g;
		my $package = "Everything::Node::$name";

		$found = $package->can($func)
			if(exists $this->{DB}->{nodetypeModules}->{$package});

		if($found)
		{
			# We need to call a function that exists in a pm.
			$RETURN = { 'SUPERtype' => $$TYPE{node_id}, 'type' => "pm",
				'name' => $package . "::" . $func };
		}
	}
	else
	{
		# The stuff is stored in the node.
		$RETURN = { 'SUPERtype' => $$TYPE{node_id}, 
			'type' => 'nodemethod', 'node' => $METHOD->getId() };
		$found = 1;
	}

	if((not $found) && ($TYPE = $TYPE->getParentType()))
	{
		# Move up the inheritence hierarchy and recursively call this.
		$RETURN = $this->getNodeMethod($func, $TYPE);
	}
			
	# Cache what we found for future reference.  However, only cache it
	# if we actually found something.
	$this->{DB}->{cache}->{methodCache}{$cacheName} = $RETURN if($RETURN);

	return $RETURN;
}


#############################################################################
#       Sub
#               getClone 
#
#       Purpose  
#               Clone this node!  This will make an exact duplicate of this node
#               and insert it into the database.  The only difference is that the
#               cloned node will have a different ID.
#
#               If sub types have special data (ie nodegroups) that would also
#               need to be cloned, they should override this function to do       
#               that work.
#
#       Parameters
#               $title - the new title of the cloned node
#               $USER - the user trying to clone this node (for permissions)
#               $workspace - the id or workspace hash into which this node
#                       should be cloned.  This is primarily for internal purposes
#                       and should not be used normally.  (NOT IMPLEMENTED YET!)
#
#       Returns
#               The newly cloned node, if successful.  undef otherwise.
#
sub getClone
{
        my ($this, $title, $USER, $workspace) = @_;
        my $CLONE;
        my $create;

        $create = "create" if($$this{type}{restrictdupes});
        $create ||= "create force";

        $CLONE = $this->{DB}->getNode($title, $$this{type}, $create);

        # if the id is not zero, the getNode found a node that already exists
        # and the type does not allow duplicate names.
        return undef if($$CLONE{node_id} > 0);

        return undef unless $CLONE->clone($this, $USER);

        return $CLONE;

}

#############################################################################
#	Sub
#		assignType
#
#	Purpose
#		This is an "private" function that should never be needed to be
#		called from outside packages.  This just assigns the node's type
#		to the {type} field of the hash.
#
sub assignType
{
	my ($this) = @_;

	if($$this{node_id} == 1)
	{
		$$this{type} = $this;
	}
	else
	{
		$$this{type} = $$this{DB}->getType($$this{type_nodetype});
	}
}


#############################################################################
#	Sub
#		cache
#
#	Purpose
#		Cache this node in the node cache (say that real fast 3 times).
#
#	Returns
#		result of cacheNode call (pretty much guaranteed to be 1)
#
sub cache
{
	my ($this) = @_;

	return unless(defined $$this{DB}->{cache});
	$$this{DB}->{cache}->cacheNode($this);
}


#############################################################################
#	Sub
#		removeFromCache
#
#	Purpose
#		Remove this object from the cache.
#
#	Returns
#		result of removeNode call (pretty much guaranteed to be 1)
# 
sub removeFromCache
{
	my ($this) = @_;

	return unless(defined $$this{DB}->{cache});
	$$this{DB}->{cache}->removeNode($this);
}


#############################################################################
#	Sub
#		quoteField
#
#	Purpose
#		Quick way to quote a specific field on this object so that it does
#		not affect the sql query.
#
#	Parameters
#		$field - the field of this object to quote (ie 
#			$this->quoteField("title");
#
#	Returns
#		The field in a quoted string form.
#
sub quoteField
{
	my ($this, $field) = @_;
	return ($$this{DB}->{dbh}->quote($$this{$field}));
}


#############################################################################
#	Sub
#		isOfType
#
#	Purpose
#		Checks to see if a node is of a certain type.
#
#	Parameters
#		$type - a nodetype node, numeric id, or string name of a type
#		$recurse - Nodetypes can derive from other nodetypes.  Superdoc
#			derives from document, and restricted_superdoc derives from
#			superdoc.  If you have a superdoc and you ask
#			isOfType('document'), you will get false unless you turn
#			on the recurse flag.  If you don't turn it on, its an easy
#			way to see if a node is of a specific type (by name, etc).
#			If you turn it on, its good to see if a node is of the
#			specified type or somehow derives from that type.
#
#	Returns
#		True if the node is of the specified type.  False otherwise.
#
sub isOfType
{
	my ($this, $type, $recurse) = @_;
	my $TYPE = $$this{DB}->getType($type);

	return 0 unless($TYPE);
	my $typeid = $TYPE->getId();
	return 1 if($typeid == $$this{type}{node_id});

	return $$this{type}->derivesFrom($TYPE) if($recurse);
	return 0;
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
	my ($this, $USER, $modes) = @_;

	# -1 is a way of specifying "super user".
	return 1 if($USER eq "-1");

	# Gods always have access to everything
	return 1 if($USER->isGod());

	my $create = 0;
	my $result = -1;

	# We need to check for create permissions separately
	$create = 1 if($modes =~ s/c//i);

	if($modes ne "")
	{
		# Figure out what permissions this user has for this node.
		my $perms = $this->getUserPermissions($USER);

		$result = Everything::Security::checkPermissions($perms, $modes);
	}

	if($create)
	{
		# If one of the flags was the create flag we need to check it
		# against the permissions that are *not* the author permissions.
		# This is because author permissions do not have create flags.
		# Its kind of a chicken/egg thing.  How can you be the author
		# if it's not created yet?  If it is created and you are the
		# author, why do you need to check (it's already created!)?
		# So to get around this, we set the author user to be something
		# non-existant to force it to use one of the other permission
		# classes.
		my $author = $$this{author_user};
		my $cresult = 0;

		$$this{author_user} = 0;

		my $perms = $this->getUserPermissions($USER);

		$modes = "c";
		$cresult = Everything::Security::checkPermissions($perms, $modes);

		# Set the author back
		$$this{author_user} = $author;

		if($result != -1)
		{
			# We need to combine the 2 results (they both must be true)
			$result = ($result && $cresult);
		}
		else
		{
			# This was a check on create only...
			$result = $cresult;
		}
	}

	return $result;

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
	my ($this, $USER) = @_;
	my $perms = $this->getDynamicPermissions($USER);
	
	if(not defined $perms)
	{
		my $class = $this->getUserRelation($USER);
		$perms = $this->getDefaultPermissions($class);
	}
	
	# Remove any '-' chars and spaces, we only want the permissions of those
	# that are on.
	$perms =~ tr/- //d;

	return $perms;
}


#############################################################################
#	Sub
#		getUserRelation
#
#	Purpose
#		Every user has some relation to every node.  They are either the
#		"author", in the "group", a "guest" user, or "other".  This will
#		return the relation the given user has with the given node.
#
#	Parameters
#		$USER - the user
#
#	Returns
#		Either "author", "group", "guest", or "other" which can be used to
#		get the appropriate permissions for the user.
#
sub getUserRelation
{
	my ($this, $USER) = @_;
	my $class;
	my $userId;
	my $sysSettings = $$this{DB}->getNode('system settings', 'setting');
	my $sysVars = $sysSettings->getVars();
	my $guest = $$sysVars{guest_user};
	
	$userId = $USER->getId();
	
	# Determine how this user relates to this node.  Is the user
	# the author, in the group, "others", or guest user?
	if($userId == $$this{author_user})
	{
		$class = "author";
	}
	elsif($userId == $guest)
	{
		$class = "guest";
	}
	else
	{
		my $usergroup = $this->deriveUsergroup();
		
		my $GROUP = $$this{DB}->getNode($usergroup);
		if($GROUP && $GROUP->inGroup($USER))
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
	my ($this) = @_;

	if($$this{group_usergroup} != -1)
	{
		return $$this{group_usergroup};
	}
	else
	{
		return $$this{type}{defaultgroup_usergroup};
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
#		A string containing valid permission characters.  The
#		strings can contain any of these characters "rwxdc-".
#
sub getDefaultPermissions
{
	my ($this, $class) = @_;
	my $TYPE = $$this{type};
	my $perms;
	my $parentPerms;
	my $field = $class . "access";
	
	$perms = $$this{$field};
	$parentPerms = $TYPE->getDefaultTypePermissions($class);
	$perms = Everything::Security::inheritPermissions($perms, $parentPerms);

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
#		$USER - the user that is trying gain access
#
#	Returns
#		The permissions flags generated by the permission code
#
sub getDynamicPermissions
{
	my ($this, $USER) = @_;
	my $class = $this->getUserRelation($USER);

	my $permission = $this->{ "dynamic${class}_permission" };

	$permission = $this->{type}{"derived_default${class}_permission"}
		if $permission and $permission == -1;

	return unless $permission and $permission > 0;

	my $PERM = $this->{DB}->getNode($permission);
	return unless $PERM;

	my $perms = eval $PERM->{code};
	Everything::logErrors( '', $@, $PERM->{code}, $PERM ) if $@;
	return $perms;
}


#############################################################################
#	Sub
#		lock
#
#	Purpose
#		For race condition purposes.  This marks a node as "locked" so
#		that others cannot access it.
#
#	*** NOTE *** Not implemented!
#
#	Returns
#		True if the lock was granted.  False if otherwise.
#
sub lock
{
	my ($this, $USER) = @_;

	return 1;
}


#############################################################################
#	Sub
#		unlock
#
#	Purpose
#		This removes the "lock" flag from a node.
#
#	*** NOTE *** Not implemented!
#
#	Returns
#		True if the lock was removed.  False if not (usually means that
#		you did not have the lock in the first place).
#
sub unlock
{
	my ($this, $USER) = @_;

	return 1;
}


#############################################################################
#	Sub
#		updateLinks
#
#	Purpose
#		A link has been traversed.  If it exists, increment its hit and
#		food count.  If it does not exist, add it.
#
#	Parameters
#		$this - (the object) the node that the link goes to
#		$FROMNODE - the node the link comes from
#		$type - the type of the link, can either refer to a nodetype, or 
#			be an arbitrary int value
#
#	Returns
#		1 if successful	
#
sub updateLinks
{
	my ($this, $FROMNODE, $type) = @_;

	return unless($FROMNODE);
	return if ($$this{node_id} == $$this{DB}->getId($FROMNODE));

	$type ||= 0;

	my $to_id = $$this{node_id};
	my $from_id = $$this{DB}->getId($FROMNODE);

	my $rows = $this->{DB}->sqlSelect( 'count(*)', 'links',
		'to_node = ? AND from_node = ? AND linktype = ?', '',
		[ $to_id, $from_id, $type ] );

	# '0E0' returned from the DBI indicates successful statement execution
	# with 0 rows affected.  They just didn't like '0 but true'.
	if ($rows and $rows ne '0E0')
	{
		$this->{DB}->sqlUpdate('links', {-hits => 'hits+1' , -food => 'food+1'},
		'from_node = ? AND to_node = ? AND linktype= ?',
		[ $from_id, $to_id, $type ] );
	}
	else
	{
		my $atts = {
			food      => 500,
			hits      => 1,
			to_node   => $to_id,
			linktype  => $type,
			from_node => $from_id,
		};
		$this->{DB}->sqlInsert( 'links', $atts );

		@$atts{qw( from_node to_node )} = @$atts{qw( to_node from_node )};
		$this->{DB}->sqlInsert( 'links', $atts ) unless $type; 
	}
	'';
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
	my ($this) = @_;
	my $id = $$this{node_id};

	$$this{DB}->sqlUpdate('node', { -hits => 'hits+1' }, "node_id=$id");

	# We will just do this, instead of doing a complete refresh of the node.
	++$$this{hits};
}


#############################################################################
#	Sub
#		getLinks
#
#	Purpose
#		Gets an array of hashes for the links that originate from this
#		node.
#
#	Parameters
#		$orderby - the field in which the sql should order the list
#
#	Returns
#		A reference to an array that contains the links
#
sub selectLinks
{
	my ($this, $orderby) = @_;

	my $obstr = $orderby ? " ORDER BY $orderby" : '';

	my $cursor = $this->{DB}->sqlSelectMany( '*', 'links',
		'from_node=?', $obstr, [$this->{node_id}]); 

	return unless $cursor;

	my @links;
	while (my $linkref = $cursor->fetchrow_hashref())
	{
		push @links, $linkref;
	}

	$cursor->finish();

	return \@links;
}


#############################################################################
#	Sub
#		getTables
#
#	Purpose
#		Get the tables that this node needs to join on to be created.
#
#	Parameters
#		$nodetable - pass 1 (true) if you want the node table included
#			in the array (the node table is usually assumed so it is
#			not included).  pass undef (nothing) or 0 (zero) if you
#			don't need the node table.
#
#	Returns
#		An array ref of the table names that this node joins on.
#		Note that the array is a copy of the internal data structures.
#		Feel free to change it or what ever you need to do.
#
sub getTables
{
	my ($this, $nodetable) = @_;

	return $$this{type}->getTableArray($nodetable);
}


#############################################################################
#	Sub
#		getHash
#
#	Purpose
#		General purpose function to get a hash structure from a field in
#		the node.
#
#	Parameters
#		$field - the field to hashify from the node
#
#	Returns
#		Hash reference, if found, undef if not.
#
sub getHash
{
	my ($this, $field) = @_;
	my $store = "hash_" . $field;

	return $this->{$store} if exists $this->{$store};

	unless (exists $this->{$field})
	{
		Everything::logErrors( "Node::getHash:\t'$field' field does not " .
			"exist for node $this->{node_id}, '$this->{title}'");
		return;
	}

	return unless $this->{$field};

	# We haven't retrieved the hash yet... do it.
	my %vars = map { split /=/ } split (/&/, $this->{$field});

	foreach (keys %vars)
	{
		$vars{$_} = Everything::Util::unescape($vars{$_});
		$vars{$_} = '' unless $vars{$_} =~ /\S/;
	}

	return $this->{$store} = \%vars;
}


#############################################################################
#	Sub
#		setHash
#
#	Purpose
#		This takes a hash of variables and assigns it to the 'vars' of the
#		given node.  If the new vars are different, we will update the
#		node.
#
#	NOTE!
#		If the vars hash contains an undefined value or the value is an
#		empty string, it will be removed from the hash as it would
#		generate a string like:
#
#		key1=value1&key2=&key3=value3
#
#		When we try to reconstruct the hash in getHash, it will fail because
#		of the 'key2='  blank value.  So, just be aware that setting a hash
#		may cause a key to be deleted.
#
#	Parameters
#		$varsref - the hashref to get the vars from
#		$field - the field of the node to set.  Different types may
#			store their hashes in different places.
#
#	Returns
#		Nothing
#
sub setHash
{
	my ($this, $varsref, $field) = @_;
	my $store = "hash_" . $field;

	# Clean out the keys that have do not have a value.
	# we use defined() because 0 is a valid value -- but not a true one
	foreach (keys %$varsref)
	{
		my $value = $$varsref{$_};
		delete $$varsref{$_} unless(defined($value) && $value ne "");
	}

	# Store the changed hash for calls to getVars
	$$this{$store} = $varsref;
	
	my $str = join("&", map( $_."=".
		Everything::Util::escape($$varsref{$_}), keys %$varsref) );

	# Put the serialized hash into the field var
	$$this{$field} = $str;

	return undef;
}


#############################################################################
#	Sub
#		getNodeDatabaseHash
#
#	Purpose
#		This will retrieve a hash of this node, but with only the keys
#		that exist in the database.  We store a lot of extra info on the
#		node and its sometimes needed to get just the keys that exist
#		in the database.
#
#	Returns
#		Hashref of the node with only the keys that exist in the database
#
sub getNodeDatabaseHash
{
	my ($this) = @_;
	my $tableArray;
	my $table;
	my @fields;
	my %keys;
	
	$tableArray = $$this{type}->getTableArray(1);
	foreach $table (@$tableArray)
	{
		# Get the fields for the table.
		@fields = $$this{DB}->getFields($table);

		# And add only those fields to the hash.
		@keys{@fields} = @$this{@fields};	
	}

	return \%keys;
}


#############################################################################
#	Sub
#		isNodetype
#
#	Purpose
#		Quickie function to see if a node is a nodetype.  This basically
#		abstracts out the isOfType(1) call.  In case nodetype is not id 1
#		in the future, we can easily change this.
#
#	Returns
#		True if this node is a nodetype, false otherwise.
#
sub isNodetype
{
	my ($this) = @_;
	
	return $this->isOfType(1);
}


#############################################################################
#	Sub
#		getParentLocation
#
#	Purpose
#		Get the parent location of this node.
#
sub getParentLocation
{
	my ($this) = @_;

	return $$this{DB}->getNode($$this{loc_location});
}


#############################################################################
#	Sub
#		toXML
#
#	Purpose
#		This returns a string that contains an XML representation for this
#		node.  Basically a way to export this node.
#
#	Notes
#		We use the XML::Generator to create the XML because the XML::DOM
#		API is not very friendly for creating XML documents as it is
#		for reading them.
#
#	Returns
#		XML string
#
sub toXML
{
	my ($this) = @_;
	my $DOC = new XML::DOM::Document();
	my $NODE;
	my $exportFields = $this->getNodeKeys(1);
	my $tag;
	my @fields;
	my @rawFields;

	push @rawFields, keys %$exportFields;

	# This is used to determine if our parser can read in a particular
	# export.  If the parser is upgraded/modified, this should be bumped
	# so that older versions of this code will know that it may have
	# problems reading in XML that generated by a newer version.
	my $XMLVERSION = "0.5";

	$NODE = new XML::DOM::Element($DOC, "NODE");

	$NODE->setAttribute("export_version", $XMLVERSION);
	$NODE->setAttribute("nodetype", $$this{type}{title});
	$NODE->setAttribute("title", $$this{title});

	# Sort them so that the exported XML has some order to it.
	@fields = sort { $a cmp $b } @rawFields;

	foreach my $field (@fields)
	{
		$NODE->appendChild(new XML::DOM::Text($DOC, "\n  "));

		$tag = $this->fieldToXML($DOC, $field, "  ");
		$NODE->appendChild($tag);
	}

	$NODE->appendChild(new XML::DOM::Text($DOC, "\n"));

	$DOC->appendChild($NODE);

	# Return the structure as a string
	return $DOC->toString();
}


#############################################################################
#	Sub
#		existingNodeMatches
#
#	Purpose
#		Mainly used for importing purposes to see of a node matching
#		this one already exists in the database.  It doesn't make much
#		sense to call this on a node that already exists.  Its pretty
#		much used for "dummy" nodes that do not exist in the database
#		yet.
#
#	Returns
#		The node in the database if one exists that matches this one
#		(matching is based on the getIdentifyingFields() method)
#		undef if no match was found.
#
sub existingNodeMatches
{
	my ($this) = @_;

	# if this already exists in the database, just return it...
	# It should be noted that if you are hitting this case, you are
	# probably doing something weird as it doesn't make sense to
	# be calling this on a node that already exists in the database.
	return $this if($$this{node_id} > 0);

	my @ID = ("title", "type_nodetype");
	my $fields = $this->getIdentifyingFields();
	push @ID, @$fields if($fields);

	my %WHERE;

	@WHERE{@ID} = @$this{@ID};
	my $NODE = $$this{DB}->getNode(\%WHERE, $$this{type});

	return $NODE;
}


#############################################################################
# End of package
#############################################################################

1;
