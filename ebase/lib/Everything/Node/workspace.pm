
=head1 Everything::Node::workspace

Class representing the workspace node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::workspace;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::setting';

use MooseX::ClassAttribute;
class_has class_nodetype => (
    reader  => 'get_class_nodetype',
    writer  => 'set_class_nodetype',
    isa     => 'Everything::Node::nodetype',
    default => sub {
        Everything::Node::nodetype->new(
            Everything::NodetypeMetaData->default_data );
    }
);

override nuke => sub {
    my ( $this, $USER ) = @_;

    return unless $this->super($USER);

    $this->{DB}->sqlDelete( 'revision', "inside_workspace=$this->{node_id}" );

    return 1;
};

1;
