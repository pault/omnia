package Everything::DB::Node::nodetype;

use Moose;

extends 'Everything::DB::Node::node';


override retrieve_node => sub {

    my ( $self, $args ) = @_;

    my $node_data = super;

    my $storage = $args->{nodebase}->get_storage;

    my $hierarchy = $storage->nodetype_hierarchy_by_id( $$node_data{ node_id } );

    $node_data->{ nodetype_hierarchy }= $hierarchy;

    return $node_data;

};

after construct_node_data_from_hash => sub {

    my ( $self, $node ) = @_;

    my $storage = $self->storage;

    my $hierarchy = $storage->nodetype_hierarchy_by_id( $$node{ node_id } );

    $node->{ nodetype_hierarchy }= $hierarchy;

    return 1;
};


around insert_node => sub {

    my $orig = shift;
    my $self = shift;
    my ($node) = @_;


    if (   not defined $node->{extends_nodetype}
        or $node->{extends_nodetype} == 0
        or $node->{extends_nodetype} == $node->{type_nodetype} )
    {
        $node->{extends_nodetype} = $self->storage->nodetype_data_by_name( 'node' )->{node_id};
    }

    $self->$orig( $node );

};

1;

__END__
