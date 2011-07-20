
=head1 Everything::Node::image

Class representing the image node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::image;

use Moose;
use MooseX::FollowPBP; 


extends 'Everything::Node::node';

has alt         => ( is => 'rw' );
has description => ( is => 'rw' );
has src         => ( is => 'rw' );
has thumbsrc    => ( is => 'rw' );

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

override dbtables => sub {
    my $self = shift;
    return 'image', $self->super();
};

1;
