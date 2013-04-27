package Everything::DB::Node::Test::nodetype;

use strict;
use warnings;
use Test::MockObject;
use Test::More;
use Scalar::Util qw/blessed/;
use Data::Dumper;

use base 'Everything::DB::Node::Test::node';

sub setup_mock_node {

    my $self = shift;

    $self->SUPER::setup_mock_node;
    $self->{node}->{extends_nodetype} = 22;
    $self->{node}->{type_nodetype} = 21;

}

sub test_insert_node :Test( +4 ) {

    my $self = shift;

    my $db_node = $self->{db_node};
    my $storage = $db_node->storage;

    $storage->set_always( -nodetype_data_by_name => { node_id => 888 } );

    my $node = $self->{node};

    ## just test that the 'extends' attribute is sane.

    my $meta = $self->db_node_class->meta;

    my $update_node = $meta->get_method ('insert_node');
    my ( $around_modifier ) = $update_node->around_modifiers;

    $node->{node_id} = 99;
    $node->{extends_nodetype} = 0;

    my $rv = $around_modifier->( sub { $node->{node_id} }, $db_node, $node);

    is ( $rv, 99, 'insert_node type nodetype returns id of stored node.' );

    is ($node->{ extends_nodetype }, 888, '...sets to node nodetype if 0.' );

    delete $$node{extends_nodetype};

    $around_modifier->( sub { $node->{node_id} }, $db_node, $node);

     is ($node->{ extends_nodetype }, 888, '...sets to node nodetype if no extends_nodetype.' );

    $$node{extends_nodetype} = $$node{type_nodetype};

    $around_modifier->( sub { $node->{node_id} }, $db_node, $node);

    is ($node->{ extends_nodetype }, 888, '...or if extends_nodetype is same as type_nodetype.' );
    $self->SUPER::test_insert_node;


}

1;
