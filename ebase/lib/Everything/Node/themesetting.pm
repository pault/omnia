
=head1 Everything::Node::themesetting

Class representing the themesetting node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::themesetting;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;

extends 'Everything::Node::setting';

has parent_theme => ( is => 'rw' );

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

override dbtables => sub {
    my $self = shift;
    return 'themesetting', $self->super;
};

1;
