
=head1 Everything::Node::node

Class representing the node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::node;

use Moose;
use MooseX::FollowPBP; 

extends 'Everything::Node';

use DBI;
use Everything::XML 'xml2node';
use Everything::NodeBase;
use Everything::XML::Node;
require Everything::Node::nodetype;   # must happen at run time not compile time

use Scalar::Util 'reftype';

has $_ => ( is => 'rw' )
  foreach
  qw/node_id type_nodetype title author_user createtime modified loc_location lockedby_user locktime authoraccess groupaccess otheraccess guestaccess dynamicauthor_permission dynamicgroup_permission dynamicother_permission dynamicguest_permission group_usergroup/;

sub destruct { 1 }

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

sub insert {
    my ( $this, $USER ) = @_;

    $this->get_nodebase->store_new_node( $this, $USER );
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

sub update {
    my ( $this, $USER, $nomodified ) = @_;
    $this->get_nodebase->update_stored_node( $this, $USER, { NOMODIFIED => $nomodified } );
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

sub nuke {
    my ( $this, $USER ) = @_;

    return $this->get_nodebase->delete_stored_node( $this, $USER );
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

sub getNodeKeys {
    my ( $this, $forExport ) = @_;
    my $keys = $this->getNodeDatabaseHash();

    if ($forExport) {

        # We want the keys that are good for exporting (ie XML), in
        # addition to the "bogus" keys that we have, there are some
        # fields that just don't make sense for exporting.
        delete @$keys{
            qw(
              createtime modified hits reputation lockedby_user locktime
              lastupdate
              )
          };

        foreach my $k ( keys %$keys ) {

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

sub isGroup {
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

sub getFieldDatatype {
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

sub clone {
    my ( $this, $NODE, $USER ) = @_;

    return unless $NODE and ( reftype($NODE) || '' ) eq 'HASH';

    my %unique = map { $_ => 1 } qw( title createtime type_nodetype type );

    foreach my $field ( keys %$NODE ) {

        # We don't want to overwrite these fields
        next if exists $unique{$field};
        next if $field =~ /_id$/;

        $this->{$field} = $NODE->{$field};
    }

    return 1;
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

sub getIdentifyingFields { }

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

sub updateFromImport {
    my ( $this, $IMPORT, $USER, $nodebase ) = @_;

    # We use the export keys
    my $keys     = $nodebase->get_storage->getNodeByIdNew ( $this->getId); #$this->getNodeKeys(1);  ## this just gets all the node attributes as a hash

    foreach my $k (keys %$keys ) {

	delete $$keys{ $k } if $k =~ /_id$/;
    }

    my $keepkeys = $this->getNodeKeepKeys();
    foreach my $key ( keys %$keys ) {
        $this->{$key} = $IMPORT->{$key} unless exists $keepkeys->{$key};
    }

    $this->{modified} = undef;
    $this->update( $USER, 'nomodify');
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

sub conflictsWith {
    my ( $this, $NEWNODE, $nodebase ) = @_;

    # if the node hasn't been modified since update, it should be ok
    return 0 unless $this->{modified} && $this->{modified} =~ /[1-9]/;

    # We use the export keys
    my $keys     = $nodebase->get_storage->getNodeByIdNew ( $this->getId); #$this->getNodeKeys(1);  ## this just gets all the node attributes as a hash

    delete @$keys{
		  qw(
			createtime modified hits reputation lockedby_user locktime
			lastupdate
		   )
		 };

    foreach my $k (keys %$keys ) {

	delete $$keys{ $k } if $k =~ /_id$/;
    }

    my $keypers = $this->getNodeKeepKeys();

    for my $keep ( keys %$keypers ) {
        delete $keys->{$keep} if exists $keys->{$keep};
    }

    foreach my $key ( keys %$keys ) {
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

sub getNodeKeepKeys {
    return {
        map { $_ => 1 }
          qw( authoraccess groupaccess otheraccess guestaccess
          dynamicguest_permission dynamicauthor_permission
          dynamicgroup_permission dynamicother_permission loc_location
          createtime )
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

sub verifyFieldUpdate {
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

sub getRevision {
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

sub undo {
    my ( $this, $USER, $redoit, $test ) = @_;

    return 0 unless $this->hasAccess( $USER, 'w' );

    my $workspace = 0;
    my $DB        = $this->{DB};

    if ( exists $DB->{workspace} ) {
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
        while ($rev_id) {
            $revisions[$rev_id] = 1;
            $rev_id = $csr->fetchrow();
        }

        my $position = $DB->{workspace}{nodes}{ $$this{node_id} };

        if ($test) {
            return 1 if $redoit     and $revisions[ $position + 1 ];
            return 1 if not $redoit and $position >= 1;
            return 0;
        }

        if ($redoit) {
            return 0 unless $revisions[ $position + 1 ];
            $position++;
        }
        else {
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

    $REVISION->{xml} =
      Everything::XML::Node->new( node => $this, nodebase => $this->{DB} )
      ->toXML();
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

sub canWorkspace {
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

sub getWorkspaced {
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

=head2 C<restrictTitle>

Prevent invalid database names from being created as titles

=over 4

=item * $node

the node containing a C<title> field to check

=back

Returns true, if the title is allowable, false otherwise.

=cut

sub restrictTitle {
    my ($this) = @_;
    return unless my $title = $this->{title};

    if ( $title =~ tr/[]|<>// ) {
        Everything::logErrors( 'node name contains invalid characters.  No'
              . 'square or angle brackets or pipes are allowed.' );
        return;
    }

    return 1;
}

1;
