
package Everything::Node::NodeTypeMetaType;

use Moose;

extends 'Everything::Node::nodetype';



around BUILDARGS => sub {
    my $orig = shift;
    my $self = shift;
    my $args = $self->$orig( @_ );

    $$args{db_package} = 'Everything::DB::Node::nodetype';

    my $nodebase = $args->{nodebase};
    my $hierarchy = $nodebase->get_storage->nodetype_hierarchy_by_id( 1 );

    $$args{nodetype_hierarchy} = $hierarchy;
    return $args;


};

override determine_db_package => sub {

    return 'Everything::DB::Node::nodetype';

};

1;
