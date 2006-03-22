=head1 Everything::Node::node

Class representing the node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::node;

use strict;
use warnings;

use DBI;
use Everything;
use Everything::NodeBase;
use Everything::XML;

sub construct { 1 }
sub destruct  { 1 }

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables { 'node' }

=head2 C<insert>

Insert this node object into the database.  If it already exists in the
database, this will do nothing, unless the operation is forced.  If it is
forced, it will make another entry (if duplicates are allowed)

Returns the node id of the node in the database.  Zero if failure.

=cut

sub insert
{
	my ( $this, $USER ) = @_;
	my $node_id = $this->{node_id};
	my ( $user_id, %tableData );

	$user_id = $USER->getId() if UNIVERSAL::isa( $USER, 'Everything::Node' );

	$user_id ||= $USER;

	return 0 unless $this->hasAccess( $USER, 'c' ) and $this->restrictTitle();

	# If the node_id greater than zero, this has already been inserted and
	# we are not forcing it.
	return $node_id if $node_id > 0;

	if ( $this->{type}{restrictdupes} )
	{

		# Check to see if we already have a node of this title.
		my $id = $this->{type}->getId();

		my $DUPELIST =
			$this->{DB}
			->sqlSelect( 'count(*)', 'node', 'title = ? AND type_nodetype = ?',
			'', [ 'title', $id ] );

		# A node of this name already exists and restrict dupes is
		# on for this nodetype.  Don't do anything
		return 0 if $DUPELIST;
	}

	# First, we need to insert the node table row.  This will give us
	# the node id that we need to use.  We need to set up the data
	# that is going to be inserted into the node table.
	foreach ( $this->{DB}->getFields('node') )
	{
		$tableData{$_} = $this->{$_} if exists $this->{$_};
	}
	delete $tableData{node_id};
	$tableData{-createtime} = $this->{DB}->now();

	# Assign the author_user to whoever is trying to insert this.
	# Unless, an author has already been specified.
	$tableData{author_user} ||= $user_id;
	$tableData{hits} = 0;

	# Fix location hell
	my $loc = $this->{DB}->getNode( $this->{type}{title}, "location" );
	$tableData{loc_location} = $loc->getId() if $loc;

	$this->{DB}->sqlInsert( 'node', \%tableData );

	# Get the id of the node that we just inserted!
	$node_id = $this->{DB}->lastValue( 'node', 'node_id' );

	# Now go and insert the appropriate rows in the other tables that
	# make up this nodetype;
	my $tableArray = $this->{type}->getTableArray();
	foreach my $table (@$tableArray)
	{
		my @fields = $this->{DB}->getFields($table);

		my %tableData;
		$tableData{ $table . "_id" } = $node_id;
		foreach (@fields)
		{
			$tableData{$_} = $this->{$_} if exists $this->{$_};
		}

		$this->{DB}->sqlInsert( $table, \%tableData );
	}

	# Now that it is inserted, we need to force get it.  This way we
	# get all the fields.  We then clear the $this hash and copy in
	# the info from the newly inserted node.  This way, the user of
	# the API just calls $NODE->insert() and their node gets filled
	# out for them.  Woo hoo!
	my $newNode = $this->{DB}->getNode( $node_id, 'force' );
	undef %$this;
	@$this{ keys %$newNode } = values %$newNode;

	# Cache this node since it has been inserted.  This way the cached
	# version will be the same as the node in the db.
	$this->cache();

	return $node_id;
}

=head2 C<update>

Update the given node in the database.

=over 4

=item * $USER

the user attempting to update this node (used for authorization)

=item * $nomodified

skip updating the modfied field, used in nodeball imports

=back

Returns the node id of the node updated if successful, 0 (false) otherwise.

=cut

sub update
{
	my ( $this, $USER, $nomodified ) = @_;

	return 0 unless $this->hasAccess( $USER, 'w' );

	if (    exists $this->{DB}->{workspace}
		and $this->canWorkspace()
		and $this->{DB}->{workspace}{nodes}{ $this->{node_id} } ne 'commit' )
	{
		my $id = $this->updateWorkspaced($USER);
		return $id if $id;
	}

	# Cache this node since it has been updated.  This way the cached
	# version will be the same as the node in the db.
	$this->{DB}->{cache}->incrementGlobalVersion($this);
	$this->cache();
	$this->{modified} = $this->{DB}->sqlSelect( $this->{DB}->now() )
		unless $nomodified;

	# We extract the values from the node for each table that it joins
	# on and update each table individually.
	my $tableArray = $this->{type}->getTableArray(1);
	foreach my $table (@$tableArray)
	{
		my %VALUES;

		my @fields = $this->{DB}->getFields($table);
		foreach my $field (@fields)
		{
			$VALUES{$field} = $this->{$field} if exists $this->{$field};
		}

		$this->{DB}->sqlUpdate(
			$table, \%VALUES,
			"${table}_id = ?",
			[ $this->{node_id} ]
		);
	}

	return $this->{node_id};
}

=head2 C<nuke>

This removes a node and all associated data with it from the database.  All
basic nodes have the node data and link data in the database.  This
implementation takes care of that data and nothing else.  If there are other
nodetypes that contain other info in the database (nodegroups, for example),
they will need to override this method and do the appropriate cleanup for their
data.  However, they should always make sure to call $this-E<gt>SUPER() at some
point so this gets executed to clean up the basic stuff.

Also note that after this is called, the node hash that the caller is holding
onto is considered a "dummy" node.  It no longer exists in the database.
However, it is still a "Node" object, so you could immediately turn around an
re-insert it and everything should be fine.

=over 4

=item * $USER

a user node object of the user trying to nuke this node.  Used for
authorization.

=back

Returns 0 (zero) if nothing was deleted (this can be caused by the node not
existing in the database, or the user not having permission).  A number
representing the number of rows deleted from the database.  Essentially, false
if the nuke failed, true if it succeeded.

=cut

sub nuke
{
	my ( $this, $USER ) = @_;
	my $result = 0;

	$this->{DB}->getRef($USER) unless $USER eq '-1';

	return 0 unless $this->hasAccess( $USER, 'd' );

	my $id = $this->getId();

	# Remove all links that go from or to this node that we are deleting
	$this->{DB}->sqlDelete( 'links', 'to_node=? OR from_node=?', [ $id, $id ] );

	# Remove all revisions of this node
	$this->{DB}->sqlDelete( 'revision', 'node_id = ?', [ $this->{node_id} ] );

	# Now lets remove this node from all nodegroups that contain it.  This
	# is a bit more complicated than removing the links as nodegroup types
	# can specify their own group table if desired.  This needs to find
	# all used group tables and check for the existance of this node in
	# any of those groups.
	foreach my $TYPE ( $this->{DB}->getAllTypes() )
	{
		my $table = $TYPE->isGroupType();
		next unless $table;

		# This nodetype is a group.  See if this node exists in any of its
		# tables.
		my $csr =
			$this->{DB}
			->sqlSelectMany( "${table}_id", $table, 'node_id = ?', undef,
			[ $this->{node_id} ] );

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
			$this->{DB}
				->sqlDelete( $table, 'node_id = ?', [ $this->{node_id} ] );

			foreach ( keys %GROUPS )
			{

				# Lastly, for each group that contains this node in its
				# group, we need to increment its global version such
				# that it will get reloaded from the database the next
				# time it is used.
				my $GROUP = $this->{DB}->getNode($_);
				$this->{DB}->{cache}->incrementGlobalVersion($GROUP);
			}
		}
	}

	# Actually remove this node from the database.
	my $tableArray = $this->{type}->getTableArray(1);
	foreach my $table (@$tableArray)
	{
		$result += $this->{DB}->sqlDelete( $table, "${table}_id = ?", [$id] );
	}

	# Now we can remove the nuked node from the cache so we don't get
	# stale data.
	$this->{DB}->{cache}->incrementGlobalVersion($this);
	$this->{DB}->{cache}->removeNode($this);

	# Clear out the node id so that we can tell this is a "non-existant" node.
	$this->{node_id} = 0;

	return $result;
}

=head2 C<getNodeKeys>

We store instance info in the hash along with the database information.  This
tends to clutter up the hash with keys/values that don't belong/exist in the
database.  So, if you need just the keys of the values that represent the
columns in the database, this function is your friend.

Everything::Node::node::getNodeKeys() implements the base for the hierarchy.

=over 4

=item * $forExport

true if you want the keys that are considered to be "exportable", 0 (false)
otherwise.  When a node is exported (ie to XML), there are some fields that
exist in the database that we don't want exported (doesn't make sense to export
the "hits" field).  Setting this to true, will cause this function to not
return any fields that don't make sense for export.

=back

Returns a hashref that is basically what you would get if you just got the data
from the database.

=cut

sub getNodeKeys
{
	my ( $this, $forExport ) = @_;
	my $keys = $this->getNodeDatabaseHash();

	if ($forExport)
	{

		# We want the keys that are good for exporting (ie XML), in
		# addition to the "bogus" keys that we have, there are some
		# fields that just don't make sense for exporting.
		delete @$keys{
			qw(
				createtime modified hits reputation lockedby_user locktime
				lastupdate
				)
			};

		foreach my $k ( keys %$keys )
		{

			# We do not want to export ids!
			delete $keys->{$k} if $k =~ /_id$/;
		}
	}

	return $keys;
}

=head2 C<isGroup>

Is this node a nodegroup?  Note, derived nodetypes that are groups will need to
override this function to return the appropriate value.

Returns the name of the table the nodegroup uses to store its group info if the
node is a nodegroup.  0 (false) if not.

=cut

sub isGroup
{
	return 0;
}

=head2 C<getFieldDatatype>

Each field in the node contains some kind of data.  This can either be a raw
value (hits = 302), a reference to a node (author_user = 184), an array of
values (usually group ids), or a hash of vars ( 'vars' field on setting).  This
is needed so that when we export a node to XML, we know what kind of datatype
the field represents.

For standard nodes, the fields are either a noderef, or a strict value.  If a
nodetype has other fields, they need to override this function and return the
appropriate type.

Valid return values are "literal_value", "noderef", "group", or "vars".

=over 4

=item * $field

the field to get the datatype of

=back

Returns either "value" or "noderef".  If a nodetype needs to return something
else, they need to override this function.

=cut

sub getFieldDatatype
{
	my ( $this, $field ) = @_;

	return 'noderef' if $field =~ /_\w+$/ and $this->{$field} =~ /^\d+$/;
	return 'literal_value';
}

=head2 C<hasVars>

Nodetypes that contain a "hash" variable table should override this and return
true.  This is a check to see if a given node has a vars setting.

=cut

sub hasVars { 0 }

=head2 C<clone>

This simply copies over the relevant keys from $NODE to the current node.  It
is the base behavior for all clone types.

=cut

sub clone
{
	my ( $this, $NODE, $USER ) = @_;

	return unless $NODE and UNIVERSAL::isa( $NODE, 'HASH' );

	my %unique = map { $_ => 1 } qw( title createtime type_nodetype type );

	foreach my $field ( keys %$NODE )
	{

		# We don't want to overwrite these fields
		next if exists $unique{$field};
		next if $field =~ /_id$/;

		$this->{$field} = $NODE->{$field};
	}

	return 1;
}

=head2 C<fieldToXML>

Given a field of this node (ie title), convert that field into an XML tag.

=over 4

=item * $DOC

the base XML::DOM::Document object that this tag belongs to

=item * $field

the field of the node to convert

=item * $indent

string that contains the amount this tag will be indented.  node::fieldToXML
does not use this.  This is for more complicated structures that want to have a
nice formatting.  This lets them know how far they are going to be indented so
they know how far to indent their children.

=back

Returns an XML::DOM::Element object that can be inserted into the parent
structure.

=cut

sub fieldToXML
{
	my ( $this, $DOC, $field, $indent ) = @_;
	return unless exists $this->{$field};

	return genBasicTag( $DOC, 'field', $field, $this->{$field} );
}

sub xmlTag
{
	my ( $this, $TAG ) = @_;
	my $tagname = $TAG->getTagName();

	unless ( $tagname =~ /field/i )
	{
		Everything::logErrors( '',
			      "node.pm does not know how to handle XML tag '$tagname' "
				. "for type '$$this{type}{title}'" );
		return;
	}

	my $PARSE = Everything::XML::parseBasicTag( $TAG, 'node' );
	my @fixes;

	# The where contains our fix
	if ( exists $PARSE->{where} )
	{
		$this->{ $PARSE->{name} } = -1;
		push @fixes, $PARSE;
	}
	else
	{
		$this->{ $PARSE->{name} } = $PARSE->{ $PARSE->{name} };
	}

	return \@fixes if @fixes;
	return;
}

=head2 C<xmlFinal>

This is called when a node has finished being constructed from an XML import.
This is when the node needs to decide whether it is updating an existing node,
or if it should insert itself as a new node.

Returns the id of the node in the database that this has been stored to.  -1 if
unable to save this.

=cut

sub xmlFinal
{
	my ($this) = @_;

	# First lets check to see if this node already exists.
	my $NODE = $this->existingNodeMatches();

	if ($NODE)
	{
		$NODE->updateFromImport( $this, -1 );
		return $NODE->{node_id};
	}
	else
	{

		# No node matches this one, just insert it.
		$this->insert(-1);
	}

	return $this->{node_id};
}

sub applyXMLFix
{
	my ( $this, $FIX, $printError ) = @_;

	unless ( exists $FIX->{fixBy} and $FIX->{fixBy} eq 'node' )
	{
		if ($printError)
		{
			my $fixBy = $FIX->{fixBy} || '(no fix by)';
			Everything::logErrors( '',
				      "node.pm does not know how to handle fix by '$fixBy'.\n"
					. "'$FIX->{where}{title}', '$FIX->{where}{type_nodetype}'\n"
			);
		}
		return $FIX;
	}

	my $where = $FIX->{where};
	my $type  = $where->{type_nodetype};

	$where = Everything::XML::patchXMLwhere($where);

	my $TYPE = $where->{type_nodetype};
	my $NODE = $this->{DB}->getNode( $where, $TYPE );

	unless ($NODE)
	{
		Everything::logErrors( '',
			      "Unable to find '$where->{title}' of type "
				. "'$where->{type_nodetype}'\nfor field '$FIX->{field}'"
				. " of node '$this->{title}', '$this->{type}{title}'\n" )
			if $printError;

		return $FIX;
	}

	$this->{ $FIX->{field} } = $NODE->{node_id};
	return;
}

=head2 C<commitXMLFixes>

After all the fixes for this node have been applied, this is called to allow
the node to save those fixes as it needs.

=cut

sub commitXMLFixes
{
	my ($this) = @_;

	# A basic node has no complex data structures, so all we need to do
	# is a simple update.
	$this->update( -1, 'nomodify' );

	return;
}

=head2 C<getIdentifyingFields>

When we export nodes to XML any fields that are pointers to other nodes.  A
nodetype that allows duplicate nodes by title, should override this method and
provide a hash of fields that differentiates this node from others.  This way,
when we import the nodes, we can tell the difference between the nodes of the
given type beyond just the title.

By default, all nodes are unique by title and type.  Since title and type are
assumed, this does nothing for the base nodes.

Returns an array ref of field names that would uniquely identify this node.
undef if none (the default title/type fields are sufficient)

=cut

sub getIdentifyingFields {}

=head2 C<updateFromImport>

This gets called when we are importing nodes from a nodeball and we have
detected that there already exists a node in the database that matches the one
we are trying to import.  This allows the the node in the database to update
itself as appropriate from the imported node, not overwriting sensitive fields
that they may not want updated (ie passwords, settings, etc).

=over 4

=item * $IMPORT

the node that we have just imported, and the data that should be merged, or
overwrite the existing data.

=back

=cut

sub updateFromImport
{
	my ( $this, $IMPORT, $USER ) = @_;

	# We use the export keys
	my $keys     = $this->getNodeKeys(1);
	my $keepkeys = $this->getNodeKeepKeys();

	foreach my $key ( keys %$keys )
	{
		$this->{$key} = $IMPORT->{$key} unless exists $keepkeys->{$key};
	}

	$this->{modified} = '0';
	$this->update( $USER, 'nomodify' );
}

=head2 C<conflictsWith>

When called on a node in the database, tests to see whether or not a new
version of the node would be OK for updateFromImport used by nbmasta to check
which nodes should be inserted

=over 4

=item * $NEWNODE

the new version of the node

=back

Returns false if ok, true if a conflict has been found.

=cut

sub conflictsWith
{
	my ( $this, $NEWNODE ) = @_;

	# if the node hasn't been modified since update, it should be ok
	return 0 unless $this->{modified} =~ /[1-9]/;

	my $keys    = $this->getNodeKeys(1);
	my $keypers = $this->getNodeKeepKeys();

	for my $keep ( keys %$keypers )
	{
		delete $keys->{$keep} if exists $keys->{$keep};
	}

	foreach my $key ( keys %$keys )
	{
		next unless exists $NEWNODE->{$key};
		return 1 if $this->{$key} ne $NEWNODE->{$key};
	}
	return 0;
}

=head2 C<getNodeKeepKeys>

This method returns a hash of keys that are kept on import changes like
permissions, locations, etc are non-critical and should be kept if the user
changes them also note, the this is a subset of getNodeKeys -- anything
excluded from getNodeKeys is assumed to be kept, or handled by the nodetype's
own updateFromImportFunction

Returns a hashref of node fields which are kept on import.

=cut

sub getNodeKeepKeys
{
	return
	{
		map { $_ => 1 }
			qw( authoraccess groupaccess otheraccess guestaccess
			    dynamicguest_permission dynamicauthor_permission
			    dynamicgroup_permission dynamicother_permission loc_location
			)
	};
}

=head2 C<verifyFieldUpdate>

This should be called during the cgiUpdate() of all FormObjects that modify a
critical node{field} directly to prevent hacked CGI parameters from breaching
security.

This is called by the FormObject stuff to verify that a particular field on a
node of this nodetype can be updated directly through the web interface.  There
are some fields that should never be able to update directly through the web
interface.  If it were possible to edit these fields, external pages with the
correct form fields and CGI parameters could be constructed to hack the site
and circumvent normal security procedures.

Any nodetypes that have data in fields that should not be allowd to be updated
directly though the web interface should override this method and provide their
own list *in addition* to this.  Derived implementations should do something
like:

  my $verify = do_their_own_verification();
  return ($verify && $this->SUPER());

=over 4

=item * $field

the field to check to see if it is ok to update directly.

=back

Returns true if it is ok to update the field directly, false otherwise.

=cut

sub verifyFieldUpdate
{
	my ( $this, $field ) = @_;

	my $restrictedFields = {
		map { $_ => 1 }

			qw( createtime node_id type_nodetype hits loc_location reputation
			    locktime lockedby_user authoraccess groupaccess otheraccess
			    guestaccess dynamicauthor_permission dynamicgroup_permission
			    dynamicother_permission dynamicguest_permission
			)
	};

	# We don't want to be able to directly modify the primary keys of
	# the various tables we join on.
	my $isID = ( $field =~ /_id$/ );
	return ( not( exists $restrictedFields->{$field} or $isID ) );
}

=head2 C<getRevision>

To retrieve a node object from the revision table, this looks,
walks, and quacks like a normal node, but only exists in the DB
in XML.

=over 4

=item * $revision

the revision_id of the node you want

=back

Returns the revision node object, if successful, otherwise 0.

=cut

sub getRevision
{
	my ( $this, $revision ) = @_;

	return 0 unless $revision =~ /^\d+$/;

	my $workspace = 0;
	$workspace = $this->{DB}->{workspace}{node_id}
		if exists $this->{DB}->{workspace};

	my $REVISION =
		$this->{DB}->sqlSelectHashref( '*', 'revision',
		"node_id = ? and revision_id = ? and inside_workspace = ?",
		'', [ $this->{node_id}, $revision, $workspace ] );

	return 0 unless $REVISION;

	my ($RN) = @{ xml2node( $REVISION->{xml}, 'noupdate' ) };
	my @copy = qw( node_id createtime reputation );
	@$RN{@copy} = @$this{@copy};

	return $RN;
}

=head2 C<logRevision>

A node is about to be updated.  Load its old settings from the database,
convert to XML, and save in the "revision" table The revision can be
re-instated with undo()  

=over 4

=item * $USER

same as update, the user who is making this revision

=back

Returns 0 if failed for any reason, otherwise the latest revision_id.

=cut

sub logRevision
{
	my ( $this, $USER ) = @_;
	return 0 unless $this->hasAccess( $USER, 'w' );

	my $workspace;
	$workspace = $this->{DB}->{workspace}{node_id}
		if ( exists $this->{DB}->{workspace} && $this->canWorkspace() );
	$workspace ||= 0;

	my $maxrevisions = $this->{type}{maxrevisions};
	$maxrevisions = $this->{type}{derived_maxrevisions} if $maxrevisions == -1;
	$maxrevisions ||= 0;

	# We should never revise a node, even if we are in a workspace.
	return 0 unless $maxrevisions;

	# we are updating the node -- remove any "redo" revisions

	if ( not $workspace )
	{
		$this->{DB}->sqlDelete(
			'revision',
			'node_id = ? and revision_id < 0 and inside_workspace = ?',
			[ $this->{node_id}, $workspace ]
		);
	}
	else
	{
		if ( exists $this->{DB}->{workspace}{nodes}{ $this->{node_id} } )
		{
			my $rev = $this->{DB}->{workspace}{nodes}{ $this->{node_id} };
			$this->{DB}->sqlDelete(
				'revision',
				'node_id = ? and revision_id > ? and inside_workspace = ?',
				[ $this->{node_id}, $rev, $workspace ]
			);
		}
	}

	my $data = $workspace
		? $this->toXML()
		: $this->{DB}->getNode( $this->getId, 'force' )->toXML();

	my $rev_id =
		$DB->sqlSelect( 'max(revision_id)+1', 'revision',
		'node_id = ? and inside_workspace = ?',
		'', [ $this->{node_id}, $workspace ] )
		|| 1;

	#insert the node as a revision
	$this->{DB}->sqlInsert(
		'revision',
		{
			xml              => $data,
			node_id          => $this->getId,
			revision_id      => $rev_id,
			inside_workspace => $workspace,
		}
	);

	# remove the oldest revision, if it's greater than the set maxrevisions
	# only if we're not in a workspace

	my ( $numrevisions, $oldest, $newest ) = @{
		$this->{DB}->sqlSelect(
			'count(*), min(revision_id), max(revision_id)',
			'revision',
			'inside_workspace = ? and node_id = ?',
			'',
			[ $workspace, $this->{node_id} ]
		)
		};

	if ( not $workspace and $maxrevisions < $numrevisions )
	{
		$this->{DB}->sqlDelete(
			'revision',
			'node_id = ? and revision_id = ? and inside_workspace = ?',
			[ $this->{node_id}, $oldest, $workspace ]
		);
	}

	return $newest;
}

=head2 C<undo>

This function implements both undo and redo -- it takes the current node,
converts to XML -- then calls xml2node on the most recent revision (in the undo
directon or redo direction).  The revision is then updated to have the current
node's XML, and its revision_id is inverted, putting it at the front of the
redo or undo stack

=over 4

=item * $redo

non-zero executes a redo

=item * $test

if this is true, don't apply the revision, just return true if the revision
exists

=back

=cut

sub undo
{
	my ( $this, $USER, $redoit, $test ) = @_;

	return 0 unless $this->hasAccess( $USER, 'w' );

	my $workspace = 0;
	my $DB        = $this->{DB};

	if ( exists $DB->{workspace} )
	{
		$workspace = $DB->{workspace}{node_id};
		return 0 unless exists $DB->{workspace}{nodes}{ $this->{node_id} };

		# you may not undo while inside a workspace unless the node is in the
		# workspace

		my $csr =
			$DB->sqlSelectMany( 'revision_id', 'revision',
			'node_id = ? and inside_workspace = ?',
			'', [ $this->{node_id}, $workspace ] );
		return unless $csr;

		my @revisions;

		my $rev_id = $csr->fetchrow();
		while ($rev_id)
		{
			$revisions[$rev_id] = 1;
			$rev_id = $csr->fetchrow();
		}

		my $position = $DB->{workspace}{nodes}{ $$this{node_id} };

		if ($test)
		{
			return 1 if $redoit     and $revisions[ $position + 1 ];
			return 1 if not $redoit and $position >= 1;
			return 0;
		}

		if ($redoit)
		{
			return 0 unless $revisions[ $position + 1 ];
			$position++;
		}
		else
		{
			return 0 unless $position >= 1;
			$position--;
		}
		$DB->{workspace}{nodes}{ $this->{node_id} } = $position;
		$DB->{workspace}->setVars( $DB->{workspace}{nodes} );
		$DB->{workspace}->update($USER);
		return 1;
	}

	my $where = "node_id=$this->{node_id} and inside_workspace=0";
	$where .= ' and revision_id < 0' if $redoit;

	my $REVISION =
		$this->{DB}->sqlSelectHashref( '*', 'revision', $where,
		'ORDER BY revision_id DESC LIMIT 1' );

	return 0 unless $REVISION;
	return 0 if $redoit     and $REVISION->{revision_id} >= 0;
	return 0 if not $redoit and $REVISION->{revision_id} < 0;
	return 1 if $test;

	my ( $xml, $revision_id ) = @$REVISION{qw( xml revision_id )};

	# prepare the redo/undo (inverse of what's being called)

	$REVISION->{xml}         = $this->toXML();
	$REVISION->{revision_id} = -$revision_id;

	my ($NEWNODE) = @{ xml2node($xml) };

	$this->{DB}->sqlUpdate(
		'revision', $REVISION,
		'node_id = ? and inside_workspace = ? and revision_id = ?',
		[ $this->{node_id}, $workspace, $revision_id ]
	);
	1;
}

=head2 C<canWorkspace>

Determine whether the current node's type allows it to be included in
workspaces.

Returns true if the node's type's canworkspace field is true, or if it's set to
inherit, and its parent canworkspace.  Otherwise false.

=cut

sub canWorkspace
{
	my ($this) = @_;

	return 0 unless $this->{type}{canworkspace};
	return 1 unless $this->{type}{canworkspace} == -1;
	return 0 unless $this->{type}{derived_canworkspace};
	1;
}

=head2 C<getWorkspaced>

We know that we have a node in a workspace, and want the node to look different
than the node in the database this function returns a node object which
reflects the state of the node in the workspace

NOTE: tricky nodetypes could overload this

Returns the node object if successful, otherwise null.

=cut

sub getWorkspaced
{
	my ($this) = @_;

	return unless $this->canWorkspace();

	# check to see if we should be returning a workspaced version of such
	my $workspace = $this->{DB}->{workspace};
	my $rev       = $workspace->{nodes}{ $this->{node_id} };

	return unless defined $rev;

	return $workspace->{cached_nodes}{"$this->{node_id}_$rev"}
		if exists $workspace->{cached_nodes}{"$this->{node_id}_$rev"};

	my $RN = $this->getRevision($rev);

	return unless $RN;
	return $workspace->{cached_nodes}{"$this->{node_id}_$rev"} = $RN;
}

=head2 C<updateWorkspaced>

This method is called by $this-E<gt>update() to handle the insertion of the
workspace into the revision table.  This also exists so that it could be
overloaded by tricky nodetypes.

=over 4

=item * $USER

the user who is updating

=back

Returns the node_id of the node, if successful otherwise null.

=cut

sub updateWorkspaced
{
	my ( $this, $USER ) = @_;

	return unless $this->canWorkspace();

	my $revision = $this->logRevision($USER);
	$this->{DB}->{workspace}{nodes}{ $this->{node_id} } = $revision;
	$this->{DB}->{workspace}->setVars( $this->{DB}->{workspace}{nodes} );
	$this->{DB}->{workspace}->update($USER);

	# however, this does pollute the cache
	$this->{DB}->{cache}->removeNode($this);

	return $this->{node_id};
}

=head2 C<restrictTitle>

Prevent invalid database names from being created as titles

=over 4

=item * $node

the node containing a C<title> field to check

=back

Returns true, if the title is allowable, false otherwise.

=cut

sub restrictTitle
{
	my ($this) = @_;
	my $title = $this->{title} or return;

	if ( $title =~ tr/[]|<>// )
	{
		Everything::logErrors( 'node name contains invalid characters.  No'
				. 'square or angle brackets or pipes are allowed.' );
		return;
	}

	return 1;
}

1;
