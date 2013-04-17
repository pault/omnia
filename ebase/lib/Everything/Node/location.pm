
=head1 Everything::Node::location

Class representing the location node.

Copyright 2000 - 2006 Everything Development Inc.

=cut

package Everything::Node::location;

use Moose;
use MooseX::FollowPBP; 

extends 'Everything::Node::node';

=head2 C<listNodes>

Get a list of all the nodes in this location, just like an 'ls'.  The nodes are
ordered by title.

=over 4

=item * $full

(optional) set to true if you want a list of node objects.  If false/undef, the
list will contain only node ids.

=back

Returns an array ref to an array that contains the nodes.

=cut

sub listNodes {
    my ( $this, $full ) = @_;

    return $this->listNodesWhere( '', '', $full );
}

=head2 C<listNodesWhere>

Get a list of all the nodes in this location, similar to doing an 'ls' with
options.  The results can be resricted and ordered as desired.

=over 4

=item * $where

(optional) a where clause.  Note that the location will already be restricted
automatically.

=item * $order

(optional) an order clause.  This defaults to ordering results by their title.

=item * $full

(optional) set to true if you want a list of node objects.  if false/undef, the
list will contain only node id's.

=back

Returns an array ref to an array that contains the nodes.

=cut

sub listNodesWhere {
    my ( $this, $where, $order, $full ) = @_;
    $where ||= '';
    $order ||= "order by title";
    $where .= " loc_location='$this->{node_id}'";

    my @nodes;

    if ( my $csr =
        $this->{DB}->sqlSelectMany( "node_id", "node", $where, $order ) )
    {
        while ( my $id = $csr->fetchrow() ) {
            $this->{DB}->getRef($id) if ($full);
            push @nodes, $id;
        }

        $csr->finish();
    }

    return \@nodes;
}

1;
