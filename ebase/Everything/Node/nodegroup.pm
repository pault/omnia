=head1 Everything::Node::nodegroup

Package that implements the base nodegroup functionality

Copyright 2000 - 2003 Everything Development Inc.

=cut

# Format: tabs = 4 spaces

package Everything::Node::nodegroup;

use strict;
use Everything;
use Everything::XML;
use XML::DOM;


#############################################################################
sub construct
{
	my ($this) = @_;

	my $group = $this->selectGroupArray();
	$$this{group} = $group;

	# We could call selectNodegroupFlat() here to have that info ready.
	# However, since that info may not be needed all the time, we will
	# save the CPU time and memory space and not call it.  If you need
	# to have the entire group, call selectNodegroupFlat() at that time.
}

=cut

=head2 C<selectGroupArray>

Gets an array of node ids of the nodes the belong to this group.

Returns an array ref of the node ids

=cut

sub selectGroupArray
{
	my ($this) = @_;
	my $groupTable = $this->isGroup();
	
	# Make sure the table exists first
	$$this{DB}->createGroupTable($groupTable);

	# construct our array of node id's of the nodes in our group
	my $cursor = $$this{DB}->sqlSelectMany('node_id', $groupTable,
		$groupTable . "_id=$$this{node_id}", 'ORDER BY orderby');
	return unless $cursor;

	my @group;
	while (my $nid = $cursor->fetchrow())
	{
		push @group, $nid;
	}
	$cursor->finish();

	return \@group;
}


#############################################################################
sub destruct
{
	my ($this) = @_;

	$this->SUPER();

	delete $this->{group};
	delete $this->{flatgroup};
}


#############################################################################
sub insert
{
	my ($this, $USER) = @_;

	return 0 unless $USER and $this->hasAccess($USER, 'c');
	
	# We need to h4x0r this a bit.  node::insert clears the $this hash.
	# This clears all fields (including our group field).  Normally,
	# we would insert the group nodes first, but the problem is, this
	# node has not been inserted yet, so we don't have a node id to
	# insert them with.  So, we hold onto the group array for now.	
	my $group  = $this->{group};
	my $return = $this->SUPER();

	# Now that the node has been inserted, we need to reassign our group
	# array.
	$this->{group} = $group;

	$this->updateGroup($USER);

	return $return;
}


#############################################################################
sub update
{
	my ($this, $USER) = @_;
	$this->updateGroup($USER);
	my $return = $this->SUPER();

	return $return;
}

sub updateFromImport
{
	my ($this, $NEW, $USER) = @_;
	
	$this->{group} = $NEW->{group};
	$this->updateGroup($USER);

	return $this->SUPER();
}


=cut

=head2 C<updateGroup>

This takes the group data that we have and compares it to what is in the
database for this group.  We determine what nodes have been inserted and what
nodes have been removed, then insert and remove them as appropriate.  Lastly we
update each group member's orderby.  This way we minimize sql deletes and
inserts and do a simple sql update.

A little discussion on groups here.  This function is a good chunk of code with
some interesting stuff going on.  With groups we need to handle the case that
the same node (same ID) may be in the group twice in different places in the
order.  In general, we don't keep duplicate nodes in a group, but it is
implemented to handle the the case of duplicates for completeness.

Group tables contain 4 columns, tablename_id, rank, node_id, and orderby.
tablename_id is set to the id of the group node that has this node (row) in its
group.  Since tablename_id can be the same for multiple rows, we need a
secondary key.  rank is the secondary key.  Each time a new row for a group is
inserted, we increment the max rank.  This way, each row has a unique key of
tablename_id,rank.  node_id is the id of the node that belongs to the group.
There can be duplicates of node_id in the same group.  Orderby exists only
because we do not want to change rank.  rank is indexed as part of the primary
key.  If we were to change rank, we would need to take the hit of the database
re-indexing on each update.  So, the orderby field is just there to allow us to
specify the order of the nodes in the group without mucking with the primary
index.

=over 4

=item * $USER

used for authentication

=back

Returns true if successful, false otherwise.

=cut

sub updateGroup
{
	my ($this, $USER) = @_;

	return 0 unless $USER and $this->hasAccess( $USER, 'w' );

	my $group = $this->restrict_type( $this->{group} );

	my %DIFF;
	my $updated  = 0;
	my $table    = $this->isGroup();
	my $orgGroup = $this->selectGroupArray();

	# We need to determine how many nodes have been inserted or removed
	# from the group.  We create a hash for each node_id.  For each one
	# that exists in the orginal group, we subract one.  For each one
	# that exists in our current group, we add one.  This way, if any
	# nodes have been removed, they will be negative (exist in the orginal
	# group, but not in the current) and any new nodes will be positive.
	# If there is no change for a particular node, it will be zero
	# (subtracted once for being in the original group, added once for
	# being in the current group).
	foreach (@$orgGroup)
	{
		$DIFF{$_} = 0 unless exists $DIFF{$_};
		$DIFF{$_}--;
	}
	foreach (@$group)
	{
		$DIFF{$_} = 0 unless exists $DIFF{$_};
		$DIFF{$_}++;
	}

	my $sql;

	# Actually remove the nodes from the group 
	foreach my $node (keys %DIFF)
	{
		my $diff = $DIFF{$node};

		if ($diff < 0)
		{
			my $abs = abs($diff);

			# diff is negative, so we need to remove abs($diff) number
			# of entries.
			my $maxrank = $this->{DB}->sqlSelect( 'max(rank)', $table,
				"${table}_id=? and node_id=?", "limit $abs" );

			next unless $maxrank;

			my $count = $maxrank - $abs;

			my $deleted = $this->{DB}->sqlDelete( $table,
				"${table}_id = ? AND node_id = ? and rank > ?",
				[ $this->{node_id}, $node, $count ] );
	
			Everything::logErrors(
				"Wrong number of group members deleted! $deleted"
			) unless $deleted == $abs;

			$updated = 1;
		}
		elsif ($diff > 0)
		{
			# diff is positive, so we need to insert $diff number
			# of new members for this particular node_id.

			# Find what the current max rank of the group is.
			my $rank = $this->{DB}->sqlSelect('MAX(rank)', $table, 
				$table . "_id=$this->{node_id}");

			$rank ||= 0;

			for(my $i = 0; $i < $diff; $i++)
			{
				$rank++;

				$this->{DB}->sqlInsert($table, {
					$table . "_id" => $this->{node_id}, 
					rank           => $rank,
					node_id        => $node,
					orderby        => 0,
				});

				$updated = 1;
			}
		}
	}

	unless ($updated)
	{
		# There were no additions, nor were any nodes removed.  However,
		# the order may have changed.  We need to check for that.
		for my $i (0 .. $#$group)
		{
			$updated = 1, last unless $$group[$i] == $$orgGroup[$i];
		}
	}

	if ($updated)
	{
		# Ok, we have removed and inserted what we needed.  Now we need to
		# reassign the orderby;

		# Clear everything to zero orderby for this group.  We need to do
		# this so that we know which ones we have updated.  If a node was
		# inserted into the middle, all of the orderby's for nodes after
		# that one would need to be incremented anyway.  This way, we reset
		# everything and update each member one at a time, and we are
		# guaranteed not to miss anything.
		$$this{DB}->sqlUpdate($table, { orderby => 0 }, $table .
			"_id=$this->{node_id}");
		
		my $orderby = 0;
		foreach my $id (@$group)
		{
			# This select statement here is only needed to get a specific row
			# and single out a node in the group.  If the database supported
			# "LIMIT #" on the update, we could just say update 'where
			# orderby=0 LIMIT 1'.  So, until the database supports that we
			# need to find the specific one we want using select
			my $rank = $this->{DB}->sqlSelect('rank', $table, $table .
				"_id=$this->{node_id} and node_id=$id and orderby=0",'LIMIT 1');

			my $sql = $table . "_id=$this->{node_id} and node_id=$id and " .
				"rank=$rank";
			$this->{DB}->sqlUpdate($table, { orderby => $orderby }, $sql);

			$orderby++;
		}
	}

	$this->{group} = $group;

	#remove from groupCache
	$this->groupUncache();

	return 1;
}

=cut

=head2 C<nuke>

Nodegroups have entries in their group table that we need to clean up before
this node goes away.  This will delete all nodegroup entries from that table,
then call SUPER to delete the node

=cut

sub nuke
{
	my ($this, $USER) = @_;	
	my $sql;
	my $table = $this->isGroup();

	$this->{DB}->getRef($USER);
	return 0 unless $this->hasAccess($USER, 'd');

	$$this{DB}->sqlDelete($table, $table . "_id=$this->{node_id}");

	# Now go delete the node!
	$this->SUPER();
}


#############################################################################
sub isGroup
{
	my ($this) = @_;
	return $this->{type}{derived_grouptable};
}


=cut

=head2 C<inGroupFast>

This just does a brute force check (which happens to be the fastest) to see if
a particular node is in a group.

NOTE: this only works for groups that do NOT contain sub groups.  If the group
contains sub groups, you will need to use inGroup().

Also note that this does not hit the database, it just does a simple check of
our group array.  This avoids an unnecessary DBI query, but if you have done
any inserts or removals without executing an update() you will be checking
against data that is not the same as what the database has.  For most general
cases, this is probably what you want (considering page loads, etc), but
something that you should be aware of.

=over 4

=item * $NODE

the node id or node hash of the node that we wish to check for group membership

=back

Returns 1 (true) if the given node is in the group, 0 (false) otherwise.

=cut

sub inGroupFast
{
	my ($this, $NODE) = @_;
	my $nodeId = $this->{DB}->getId($NODE);

	$this->groupCache();
	return $this->existsInGroupCache($nodeId);
}

=cut

=head2 C<inGroup>

This checks to see if the given node belongs to the given group.  This will
check all sub groups.  If you know for a fact that your group does not contain
sub groups, you will probably want to call inGroupFast() instead as it will be
significantly faster in most cases.

=over 4

=item * NODE

the node id or node hash of the node that we wish to check for group membership

=back

Returns 1 (true) if the given node is in the group, 0 (false) otherwise.

=cut

sub inGroup
{
	my ($this, $NODE) = @_;
	return 0 unless $NODE;

	my $nodeId = $this->{DB}->getId($NODE);

	$this->groupCache( $this->selectNodegroupFlat() )
		unless $this->hasGroupCache();

	return $this->existsInGroupCache($nodeId);
}

=cut

=head2 C<selectNodegroupFlat>

This recurses through the nodes and node groups that this group contains
getting the node hash for each one on the way.

=over 4

=item * $NODE

the group node to get node hashes for.

=back

Returns a reference to an array of node hashes that belong to this group.

=cut

sub selectNodegroupFlat
{
	my ($this, $groupsTraversed) = @_;

	# If we have already calculated this group, return it.
	return $this->{flatgroup} if exists $this->{flatgroup};

	# If groupsTraversed is not defined, initialize it
	$groupsTraversed ||= {};

	# return if we have already been through this group.  Otherwise,
	# we will get stuck in infinite recursion.
	return if exists $groupsTraversed->{ $this->{node_id} };
	$groupsTraversed->{ $this->{node_id} } = $this->{node_id};
	
	my @nodes;
	foreach my $node_id (@{ $$this{group} })
	{
		my $NODE = $this->{DB}->getNode($node_id);
		next unless defined $NODE;
		
		if ($NODE->isGroup())
		{
			my $group = $NODE->selectNodegroupFlat($groupsTraversed);
			push @nodes, @$group if defined $group;
		}
		else
		{
			push @nodes, $NODE;
		}
	}
	
	return $this->{flatgroup} = \@nodes;
}

=cut

=head2 C<insertIntoGroup>

This will insert a node(s) into a nodegroup.  THIS DOES NOT UPDATE THE NODE IN
THE DATABASE!  After inserting a node into a group, you must call update() to
update the changes.

=over 4

=item * $USER

the user trying to add to the group (used for authorization)

=item * $insert

the node or array of nodes to insert into the group

=item * $orderby

the criteria of which to order the nodes in the group.  This is zero-based.
Meaning that 0 (zero) will insert at the very beginning of the group.

=back

Returns true (1) if the insert was successful.  If you had previously called
selectNodegroupFlat(), you will need to do so again to refresh the list.  False
(0), if the user does not have permissions, or failure.

=cut

sub insertIntoGroup
{
	my ($this, $USER, $insert, $orderby) = @_;
	my $group = $this->{group};

	return 0 unless $USER and $insert and $this->hasAccess($USER, 'w');
	
	# converts to a list reference w/ 1 element if we get a scalar
	my $insertref = [$insert] unless UNIVERSAL::isa( $insert, 'ARRAY');

	$insertref = $this->restrict_type($insertref);

	my $len = int(@$group);
	$orderby ||= $len;
	$orderby = ($orderby > $len ? $len : $orderby);

	# Make sure we only have id's
	foreach (@$insertref)
	{
		$_ = $this->{DB}->getId($_);
	}
	
	# Insert the new nodes into the group array at the orderby offset.
	splice(@$group, $orderby, 0, @$insertref);

	$this->{group} = $group;

	# If a flatgroup exists, it is no longer valid.
	delete $this->{flatgroup};
	
	# Wipe out any cached group
	$this->groupUncache();

	return 1;
}

=cut

=head2 C<removeFromGroup>

Remove a node from a group.  THIS DOES NOT UPDATE THE NODE IN THE DATABASE! You
need to call update() to commit the changes to the database.

=over 4

=item * $NODE

the node to remove

=item * $USER

the user who is trying to do this (used for authorization)

=back

Returns true (1) if the node was successfully removed from the group, false (0)
otherwise.  If you had previously called selectNodegroupFlat(), you will need
to call it again since things may have significantly changed.

=cut

sub removeFromGroup 
{
	my ($this, $NODE, $USER) = @_;
	my $success;
	
	return 0 unless $USER and $NODE and $this->hasAccess($USER, 'w');

	my $node_id = $this->{DB}->getId($NODE);
	my $group   = $this->{group};

	# manipulate group in place for a speed boost
	my $pos = 0;
	while ($pos < $#{ $group })
	{
		$pos++, next unless $group->[ $pos ] == $node_id;
		splice( @$group, $pos, 1 );
	}

	# If a flatgroup exists, it is no longer valid.
	delete $this->{flatgroup};

	#remove from groupCache
	$this->groupUncache();

	return 1;
}

=cut

=head2 C<replaceGroup>

This removes all nodes from the group and inserts new nodes.

=over 4

=item * $REPLACE

A node id or array of node id's to be inserted

=item * $USER

the user trying to do this (used for authorization).

=back

Returns true if successful, false otherwise

=cut

sub replaceGroup
{
	my ($this, $REPLACE, $USER) = @_;
	my $groupTable = $this->isGroup();

	return 0 unless $this->hasAccess($USER, 'w'); 
	
	$REPLACE = [$REPLACE] unless UNIVERSAL::isa($REPLACE, 'ARRAY');

	$REPLACE = $this->restrict_type($REPLACE);

	# Just replace the group
	$this->{group} = $REPLACE;

	# If a flatgroup exists, it is no longer valid.
	delete $this->{flatgroup};

	# Remove it from the groupCache
	$this->groupUncache();

	return 1;
}

=cut

=head2 C<getNodeKeys>

=cut

sub getNodeKeys
{
	my ($this, $forExport) = @_;
	my $keys = $this->SUPER();
	
	if ($forExport)
	{
		# Groups are special.  There is one field that we do want to
		# include for export... the group field that is generated
		# when the group node is constructed.
		$keys->{group} = $this->{group};
	}

	return $keys;
}

=cut

=head2 C<fieldToXML>

Convert the field that contains the group structure to an XML format.

=over 4

=item * $DOC

the base XML::DOM::Document object that contains this structure

=item * $field

the field of the node to convert (if it is not the group field, we just call
SUPER())

=item * $indent

string that contains the spaces that this will be indented

=back

=cut

sub fieldToXML
{
	my ($this, $DOC, $field, $indent) = @_;

	if ($field eq 'group')
	{
		my $GROUP       = XML::DOM::Element->new($DOC, 'group');
		my $indentself  = "\n" . $indent;
		my $indentchild = $indentself . "  ";

		foreach my $member (@{ $this->{group} })
		{
			$GROUP->appendChild(XML::DOM::Text->new($DOC, $indentchild));
			
			my $tag = genBasicTag($DOC, 'member', 'group_node', $member);
			$GROUP->appendChild($tag);
		}

		$GROUP->appendChild(XML::DOM::Text->new($DOC, $indentself));

		return $GROUP;
	}
	else
	{
		return $this->SUPER();
	}
}


#############################################################################
sub xmlTag
{
	my ($this, $TAG) = @_;
	my $tagname = $TAG->getTagName();

	if ($tagname eq 'group')
	{
		my @fixes;
		my @childFields = $TAG->getChildNodes();
		my $orderby     = 0;

		foreach my $child (@childFields)
		{
			next if $child->getNodeType() == XML::DOM::TEXT_NODE();

			my $PARSE = Everything::XML::parseBasicTag($child, 'nodegroup');

			if (exists $PARSE->{where})
			{
				$PARSE->{orderby} = $orderby;
				$PARSE->{fixBy}   = 'nodegroup';

				# The where contains our fix
				push @fixes, $PARSE;

				# Insert a dummy node into the group which we can later fix.
				$this->insertIntoGroup(-1, -1, $orderby);
			}
			else
			{
				$this->insertIntoGroup(-1, $PARSE->{ $PARSE->{name} },$orderby);
			}

			$orderby++;
		}

		return \@fixes if @fixes;
	}
	else
	{
		return $this->SUPER();
	}

	return;
}

=cut

=head2 C<applyXMLFix>

In xmlTag, we returned a hash indicating that we were unable to find a node
that one of our group members referenced.  All nodes should be installed now,
so we need to go find it and fix the reference.

=over 4

=item * $FIX

the fix that we returned from xmlTag()

=item * $printError

set to true if errors should be printed to stdout

=back

Returns undef if the patch was successful, $FIX if we were still unable to find
the node.

=cut

sub applyXMLFix
{
	my ($this, $FIX, $printError) = @_;

	return $this->SUPER() unless $FIX->{fixBy} eq 'nodegroup';

	my $where = Everything::XML::patchXMLwhere($FIX->{where});
	my $TYPE  = $where->{type_nodetype};
	my $NODE  = $this->{DB}->getNode($where, $TYPE);

	unless ($NODE)
	{
		Everything::logErrors( '',
			"Unable to find '$where->{title}' of type " .
			"'$where->{type_nodetype}'\n for field '$where->{field}'\n" .
			" in node '$this->{title}' of type '$this->{type}{title}'"
		 ) if $printError;

		return $FIX;
	}

	my $group = $this->{group};

	# Patch our group array with the now found node id!
	$group->[$FIX->{orderby}] = $NODE->{node_id};

	return;
}

=cut

=head2 C<clone>

Clone the node!  The normal clone doesn't duplicate members of a nodegroup, so
we have to do it here specifically.

=over 4

=item * $USER

the user trying to clone this node (for permissions)

=item * $newtitle

the new title of the cloned node

=item * $workspace

the id or workspace hash into which this node should be cloned.  This is
primarily for internal purposes and should not be used normally.  (NOT
IMPLEMENTED YET!)

=back

Returns the newly cloned node, if successful.  undef otherwise.

=cut

sub clone
{
	my $this = shift;

	# we need $USER for Everything::Node::node::clone() _and_ insertIntoGroup
	my ($USER) = @_;
	my $NODE   = $this->SUPER(@_);
	return unless defined $NODE;

	$NODE->insertIntoGroup($USER, $this->{group}) if exists $this->{group};

	# Update the node since the new group info has not been saved yet.
	$NODE->update($USER);

	return $NODE;
}

=cut

=head2 C<restrict_type>

Some nodegroups can only hold nodes of a certain type.  This takes a reference
to a list of nodes to insert and removes any that don't fit.  It also allows
nodegroups that have the same restriction -- a usergroup can hold user nodes
and other usergroups.

=over 4

=item * $groupref

a reference to a list of nodes to insert into the group

=back

Returns a reference to a list of nodes allowable in this group.

=cut

sub restrict_type
{
    my ($this, $groupref) = @_;
    my $restricted_type;

	# anything is allowed without a valid restriction
	my $nodetype = getNode($this->{type_nodetype});
    return $groupref unless $restricted_type = $nodetype->{restrict_nodetype};

    my @cleaned;

    foreach my $group (@$groupref) 
	{
        my $node = getNode($group);

		# check if the member matches directly
        if ($node->{type_nodetype} == $restricted_type) 
		{
            push @cleaned, $group;
        } 

		# check if the member is a nodegroup with similar restrictions
		elsif (defined($node->{type}{restrict_nodetype}))
		{
			push @cleaned, $group
				if $node->{type}{restrict_nodetype} == $restricted_type;
		}
    }
    return \@cleaned;
}

sub getNodeKeepKeys
{
	my ($this) = @_;

	my $nodekeys       = $this->SUPER();
	$nodekeys->{group} = 1;

	return $nodekeys;
}

sub conflictsWith
{
	my ($this, $NEWNODE) = @_;

    return 0 unless $this->{modified} =~ /[1-9]/;
	my ($old, $new) = ( $this->{group}, $NEWNODE->{group} );
	return 1 unless @$new == @$old;

	for my $pos (0 .. $#{ $new })
	{
		return 1 unless $new->[ $pos ] == $old->[ $pos ];
	}

	$this->SUPER();
}

#############################################################################
# PRIVATE: Group caching functions
#############################################################################

# The group caching code is stored here rather than in NodeCache.pm because
# we need to intelligently cache something, IE only bother doing so if
# someone is going to call inGroup or inGroupFast on a nodegroup; otherwise
# we are simply wasting our cycles and memory mapping into the nodecache hash
# Originally inspired by a hack nate threw into E2.
#
# This consists of four functions
# 
# hasGroupCache($this)
# groupCache($this)
# groupUncache($this)
# existsInGroupCache($this, node_id)
#
# I wouldn't do it this way unless we got ridiculous speed out of it, which
# we do.

sub hasGroupCache
{
	my ($this) = @_;
	return exists $this->{DB}->{cache}->{groupCache}->{$this->{node_id}};
}

sub getGroupCache
{
  my ($this) = @_;
  return $this->{DB}->{cache}->{groupCache}->{$$this{node_id}}; 
}

sub groupCache
{
	my ($this, $group) = @_;
	$group ||= $this->{group};

	return 1 if $this->hasGroupCache();
	%{$this->{DB}->{cache}->{groupCache}->{$this->{node_id}}}
		= map {$_ => 1} @$group;
}

sub groupUncache
{
	my ($this) = @_;
	
	delete $this->{DB}->{cache}->{groupCache}->{$this->{node_id}};	
}

sub existsInGroupCache
{

	my ($this, $nid) = @_;
	return
		exists $this->{DB}->{cache}->{groupCache}->{$this->{node_id}}->{$nid};
}

#############################################################################
# End of package
#############################################################################

1;
