package Everything::DB::Nodetype;


use Moose;
use strict;
use warnings;

has 'nodetype' => ( is => 'rw', isa => 'Everything::DB::Nodetype', weakref => 1, );


# returns a hash ref of node keys and values when we know the id, according to the nodetype in 'nodetype'

sub node_data_by_id {


}

# returns a hash ref of node keys and values when we know the name, according to the nodetype in 'nodetype'

sub node_data_by_name {


}

# returns an array ref of node ids when we know the nodetype
sub select_node_where {



}

# returns 'node cursor', that is an object return by DBI over which we can iterate the results.

sub get_node_cursor {


}
