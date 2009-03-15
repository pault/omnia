package Everything::DB::Node::nodetype;

use Moose;

extends 'Everything::DB::Node::node';


after construct_node_data_from_hash => sub {

    my ( $self, $node ) = @_;

    my $storage = $self->storage;

    my $hierarchy = $storage->nodetype_hierarchy_by_id( $$node{ node_id } );

    $node->{ nodetype_hierarchy }= $hierarchy;

    return 1;
};


1;

__END__
