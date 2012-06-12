
=head1 Everything::Node::nodetype

Class representing the nodetype node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::nodetype;

use Moose;
use MooseX::FollowPBP; 


extends 'Everything::Node::node';

has $_ => ( is => 'rw' )
  foreach (
    qw/nodetype_id restrict_nodetype extends_nodetype restrictdupes sqltable grouptable defaultauthoraccess defaultgroupaccess defaultotheraccess defaultguestaccess defaultgroup_usergroup defaultauthor_permission defaultgroup_permission defaultother_permission defaultguest_permission maxrevisions canworkspace/
  );

has nodetype_hierarchy => ( is => 'rw' );

use Everything::Security;

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

override dbtables => sub {
    my $self = shift;
    return 'nodetype', super;
};

=head2 C<construct>

The constructor for a nodetype is rather involved.  We derive the nodetype when
it is constructed.  If a nodetype up the chain changes, the cache needs to be
flushed so that the nodetype gets re-constructed with the new data.

=cut

sub BUILD {
    my ($this) = @_;

    my $hierarchy;
    return unless $hierarchy = $this->get_nodetype_hierarchy;

    # Now we need to derive ourselves and assign the derived values
    my $PARENT;

    $this->{extends_nodetype} = 0 unless defined $this->{extends_nodetype};

    return unless defined $this->{node_id};

    my $derive = {
        map { $_ => 1 }
          qw( sqltable maxrevisions
          canworkspace
          )
    };

    # Copy the fields that are to be derived into new hash entries.  This
    # way we can keep the actual "node" data clean.  That way if/when we
    # update this node, we don't corrupt the database.

    my @user_classes = qw/author group other guest/;

    my $accesses = Everything::NodeBase->default_type_access( $hierarchy );

    map { $this->{ 'derived_default' . $_ . 'access' } = $$accesses{ $_ } } @user_classes;

    my $permissions = Everything::NodeBase->default_type_permissions( $hierarchy );
    map { $this->{ 'derived_default' . $_ . '_permissions' } = $$permissions{ $_ } } @user_classes;

    $this->{ 'derived_defaultgroup_usergroup' } = Everything::NodeBase->default_type_usergroup( $hierarchy );

    $this->{derived_grouptable} = Everything::DB->derive_grouptable( $hierarchy );

    my $db_settings = Everything::NodeBase->derive_storage_settings( $hierarchy );

    foreach ( qw/maxrevisions canworkspace / ) {
	$this->{"derived_$_"}= $$db_settings{ $_ };
    }

    $this->{tableArray} = Everything::DB->derive_sqltables( $hierarchy );

    return 1;
}

sub destruct {
    my ($this) = @_;

    # Release any object refs that we got
    delete $this->{tableArray};

    # Delete the base stuff
    #$this->SUPER();
}

=head2 C<insert>

Make new nodetypes derive from 'node' automatically if they do not have a
parent specified.

Returns the inserted node id

=cut

before insert => sub {
    my $this = shift;

    if (   not defined $this->{extends_nodetype}
        or $this->{extends_nodetype} == 0
        or $this->{extends_nodetype} == $this->{type_nodetype} )
    {
        $this->{extends_nodetype} = $this->{DB}->getType('node')->{node_id};
    }

};

=head2 C<update>

This allows the default "node" to actually update our node, but we need to
flush the cache in the case of an update to a nodetype due to the fact that
some other nodetypes may derive from this nodetype.  Those derived nodetypes
would need to be reloaded and reinitialized, otherwise we may get weird data.

=cut

override update => sub {
    my $this   = shift;
    my $result = $this->super;

    # If the nodetype was successfully updated, we need to flush the
    # cache to make sure all the nodetypes get reloaded.
    $this->{DB}{cache}->flushCacheGlobal() if $result;

    return $result;
};

=head2 C<nuke>

This keeps the user from accidentally deleting a nodetype for which nodes still
exist.

=cut

override nuke => sub {
    my ( $this, $USER ) = @_;

    if ( $this->{DB}->getNode( { type_nodetype => $this->{node_id} } ) ) {
        Everything::logErrors("Can't delete. Nodes of this type still exist");
        return 0;
    }

    return super;
};

=head2 C<getTableArray>

Every nodetype keeps an array of the tables that nodes of its type need to join
on.  This will return an array of those table names.

=over 4

=item * $nodeTable

the node table is usually assumed, but if you want it included, pass true (ie
1).  undef otherwise.

=back

Returns an array ref of the table names that nodes of this type need to join
on.  Note that this array is a copy so feel free to modify it in any way.

=cut

sub getTableArray {
    my ( $this, $nodeTable ) = @_;
    my @tables;

    Everything->deprecate("Use Everything::DB::retrieve_nodetype_table instead.");

    push @tables, @{ $this->{tableArray} } if defined $this->{tableArray};
    push @tables, 'node' if $nodeTable;

    return \@tables;
}

=head2 C<getDefaultTypePermissions>

This gets the default permissions for the given nodetype.  This is NOT the
permissions for the nodetype itself.  Rather, these are the permissions that
nodes of this type inherit from.  Hence, the default TYPE permissions.

=over 4

=item * $class

the class of user.  Either "author", "group", "guest", or "other".  This can be
obtained by calling getUserNodeRelation().

=back

Returns a string that contains the default permissions of the given nodetype.

=cut

sub getDefaultTypePermissions {
    my ( $this, $class ) = @_;

    my $field = "derived_default" . $class . "access";
    return $this->{$field} if exists $this->{$field};
}

=head2 C<getParentType>

Get the parent nodetype that this nodetype derives from.

Returns a nodetype that this nodetype derives from, undef if this nodetype does
not derive from anything.

=cut

sub getParentType {
    my ($this) = @_;

    return unless $this->{extends_nodetype};
    return $this->{DB}->getType( $this->{extends_nodetype} );
}

=head2 C<hasTypeAccess>

The hasAccess() function in Node.pm checks permissions on a specific node.  If
you call that on a nodetype, you are checking the permissions for that node,
NOT the permissions for all nodes of that type.

This checks permissions for the default permissions for all nodes of this type.
This is useful for checking permissions for create operation since the node you
are trying to create does not yet exist so you can't test the access on it.

=over 4

=item * $USER

the user to check access for

=item * $modes

same as hasAccess()

=back

Returns 1 (true) if the user has access to all modes given, 0 (false)
otherwise.  The user must have access for all modes given for this to return
true.  For example, if the user has read, write and delete permissions, and the
modes passed were "wrx", the return would be 0 since the user does not have the
"execute" permission.

=cut

sub hasTypeAccess {
    my ( $this, $USER, $modes ) = @_;

    # Create a dummy node of this type to do a check on.
    my $dummy =
      $this->{DB}->getNode( 'dummy_access_node', $this, 'create force' );

    return $dummy->hasAccess( $USER, $modes );
}

=head2 C<isGroupType>

Check to see if this type is a group (ie nodes of this type are nodegroup
nodes).

Returns the name of the group table if this is a group type, false otherwise.

=cut

sub isGroupType {
    my ($this) = @_;

    return $this->{derived_grouptable};
}

=head2 C<derivesFrom>

Given a nodetype, check to see if this nodetype descends from it in some way.
For example, restricted_superdoc -E<gt> superdoc -E<gt> document.  Calling
$restrictedSuperdoc-E<gt>derivesFrom("document") would return true.

=over 4

=item * $type

the nodetype to check to see if we derive from.  Either a string name, or a
nodetype object.

=back

Returns true if the this derives from the given nodetype, false otherwise.

=cut

sub derivesFrom {
    my ( $this, $type ) = @_;

    $type = $this->{DB}->getType($type);
    return 0 unless $type and $type->{type_nodetype} == 1;

    my $check = $this;

    while ($check) {
        return 1 if $type->{node_id} == $check->{node_id};
        $check = $check->getParentType();
    }

    return 0;
}

sub getNodeKeepKeys {
    my ($this) = @_;

    my %nodekeys = %{ $this->SUPER() };

    my $ntkeys = {
        map { $_ => 1 }
          qw( defaultauthoraccess defaultgroupaccess defaultotheraccess
          defaultguestaccess defaultgroup_usergroup defaultauthor_permission
          defaultgroup_permission defaultother_permission
          defaultguest_permission
          )
    };

    # permissions will prevail in the current version

    @nodekeys{ keys %$ntkeys } = values %$ntkeys;

    \%nodekeys;
}


## these methods get nodes from the nodebase.  Each nodetype might be
## constructed from the nodebase in its own unique way. Nodetypes
## manage the relationship of a node to the nodebase/db, so this is an
## ideal place for this SQL. Possibly spin this out into a Role.


=head2 node

Retrieves a node of this nodetype from the database.

Arguments:

=over 

=item node id or name

=item nodebase

=back

=cut

sub node {



}

=head2 insert_node

Takes a blessed node object and then inserts it into the nodebase

=over

=item node

=item nodebase

=back

=cut

=head2 update_node

Takes a blessed node object and updates the existing node in the database.

=cut

sub update_node {


}

1;
