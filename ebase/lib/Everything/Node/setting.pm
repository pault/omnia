
=head1 Everything::Node::setting

Class representing the setting node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::setting;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;

extends 'Everything::Node::node';

use Everything::Security;
use Scalar::Util 'reftype';

has vars => ( is => 'rw' );

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

override dbtables => sub {
    my $self = shift;
    return 'setting', $self->super(@_);
};

=head2 C<getVars>

All setting nodes join on the setting table.  The vars field in that table
contains a string that is an '&' delimited hash.  This function will grab that
string and construct a perl hash out of it.

=cut

sub getVars {
    my ($this) = @_;

    return $this->getHash("vars");
}

=head2 C<setVars>

This takes a hash of variables and assigns it to the 'vars' of the given node.
NOTE!  This will not update the node.  It will only update the local version of
the vars for this node instance.  If you want to update the node in the
database, you will need to call update on this node.

=over 4

=item * $varsref

the hashref to get the vars from

=back

Returns nothing.

=cut

sub setVars {
    my ( $this, $vars ) = @_;

    $this->setHash( $vars, "vars" );

    return;
}

sub hasVars { 1 }

override getNodeKeepKeys => sub {
    my ($this) = @_;

    my $nodekeys = $this->super();
    $nodekeys->{vars} = 1;

    return $nodekeys;
};

# vars are preserved upon import
before updateFromImport => sub {
    my ( $this, $NEWNODE, $USER ) = @_;

    my $V    = $this->getVars();
    my $NEWV = $NEWNODE->getVars();

    @$NEWV{ keys %$V } = values %$V;

    $this->setVars($NEWV);

};

1;
