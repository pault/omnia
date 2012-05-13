
=head1 Everything::Node::workspace

Class representing the workspace node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::workspace;

use Moose;
use MooseX::FollowPBP; 

extends 'Everything::Node::setting';

override nuke => sub {
    my ( $this, $USER ) = @_;

    return unless $this->super($USER);

    $this->{DB}->sqlDelete( 'revision', "inside_workspace=$this->{node_id}" );

    return 1;
};

1;
