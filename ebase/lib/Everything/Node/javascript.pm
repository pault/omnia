
=head1 Everything::Node::javascript

Class representing the javascript node.

Copyright 2006 Everything Development Inc.

=cut

package Everything::Node::javascript;

use strict;
use warnings;

use Moose::Policy 'Moose::Policy::FollowPBP';
use Moose;

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

extends 'Everything::Node::node';

has code    => ( is => 'rw' );
has dynamic => ( is => 'rw' );
has comment => ( is => 'rw' );

with 'Everything::Node::Parseable';

=head2 C<dbtables()>

Returns a list of tables this node uses in the database, most specific first.

=cut

sub dbtables {
    my $self = shift;
    return 'javascript', $self->SUPER::dbtables();
}

1;
