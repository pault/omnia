
=head1 Everything::Node::user

Class representing the user node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::user;

use Moose;
use MooseX::FollowPBP; 


extends 'Everything::Node::setting';

has doctext          => ( is => 'rw' );
has email            => ( is => 'rw' );
has inside_workspace => ( is => 'rw' );
has karma            => ( is => 'rw' );
has nick             => ( is => 'rw' );
has realname         => ( is => 'rw' );
has passwd           => ( is => 'rw' );

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

override dbtables => sub {
    my $self = shift;
    return qw( user document ), $self->super();
};

=head2 C<insert>

We want all users to default to be owned by themselves.

=cut

override insert => sub {
    my ( $this, $USER ) = @_;

    return 0 unless my $id = $this->super($USER);

    # Make all new users default to owning themselves.
    $this->{author_user} = $id;

    $this->update($USER);

    return $id;
};

=head2 C<isGod>

Checks to see if the given user is a god (in the gods group).

=over 4

=item * $recurse

for speed purposes, this assumes that the gods group is flat (it does not
contain any other nodegroups that it would need to traverse).  However, if the
gods group does contain nested groups, you can pass true here to check
everything.  Note that turning this on is significantly slower.

=back

Returns true if the given user is a "god".  False otherwise.

=cut

sub isGod {
    my ( $this, $recurse ) = @_;
    my $GODS = $this->{DB}->getNode( 'gods', 'usergroup' );

    return 0 unless $GODS;

    return $GODS->inGroup($this) if $recurse;
    return $GODS->inGroupFast($this);
}

=head2 C<isGuest>

Checks to see if the given user is the guest user.  Certain system nodes need
to exist for this check, if they do not, this will default to true for security
purposes.

Returns true if the user is the guest user, false otherwise.

=cut

sub isGuest {
    my ($this) = @_;

    my $SYS = $this->{DB}->getNode( 'system settings', 'setting' ) or return 1;
    my $VARS = $SYS->getVars() or return 1;

    return ( $VARS->{guest_user} == $this->{node_id} );
}

sub getNodeKeys {
    my ( $this, $forExport ) = @_;
    my $keys = $this->SUPER($forExport);

    # Remove these fields if we are exporting user nodes.
    delete @$keys{qw( passwd lasttime )} if $forExport;

    return $keys;
}

=head2 C<verifyFieldUpdate>

See Everything::Node::node::verifyFieldUpdate() for info.

=cut

sub verifyFieldUpdate {
    my ( $this, $field ) = @_;

    my $restrictedFields = {
        title    => 1,
        karma    => 1,
        lasttime => 1,
    };

    my $verify = not exists $restrictedFields->{$field};
    return $verify && $this->SUPER();
}

# no conflicts if the user exists
sub conflictsWith { 0 }

# we don't allow user nodes to update
sub updateFromImport { 0 }

=head2 C<restrictTitle>

Prevent invalid characters in usernames (and optional near-duplicates)

=over 4

=item * $node

the node containing a C<title> field to check

=back

Returns true, if the title is allowable, false otherwise.

=cut

sub restrictTitle {
    my ($this) = @_;
    my $title = $this->{title} or return;

    return $title =~ tr/-<> !a-zA-Z0-9_//c ? 0 : 1;
}

=head2 C<getNodelets>

Get the nodelets for the user, using the defaults if necessary.

=over 4

=item * $defaultGroup

the default nodelet group to use

=back

Returns a reference to a list of nodelets to display.

=cut

sub getNodelets {
    my ( $this, $defaultGroup ) = @_;
    my $VARS = $this->getVars();

    my @nodelets;
    @nodelets = split( /,/, $VARS->{nodelets} ) if exists $VARS->{nodelets};

    return \@nodelets if @nodelets;

    my $NODELETGROUP;
    $NODELETGROUP = $this->{DB}->getNode( $VARS->{nodelet_group} )
      if exists $VARS->{nodelet_group};

    push @nodelets, @{ $NODELETGROUP->{group} }
      if $NODELETGROUP
          and $NODELETGROUP->isOfType('nodeletgroup');

    return \@nodelets if @nodelets;

    # push default nodelets on
    return $this->{DB}->getNode($defaultGroup)->{group};
}

1;
