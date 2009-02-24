
=head1 Everything::Node::superdoc

Class representing the superdoc node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::superdoc;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;
extends 'Everything::Node::document';

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

with 'Everything::Node::Parseable';

sub get_compilable_field { 'doctext' }

1;
