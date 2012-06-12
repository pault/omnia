

package Everything::NodeBase::NodetypeRegister;

use Moose::Role;

has nodetype_modules => (  is => 'rw', default => sub{ {} } );
has nodetype_ids => (  is => 'rw', default => sub{ {} } );
has nodetype_titles => (  is => 'rw', default => sub{ {} });

=head2 nodetype

Takes one argument which is a package name.

Returns the nodetype node that corresponds to it.

=cut

sub nodetype {

    my ( $self, $class ) = @_;

    return $self->nodetype_modules->{$class};

}


=head2 nodetype_by_title

Takes one argument which is the title of the nodetype.

Returns the nodetype node that corresponds to it.

=cut

sub nodetype_by_title {

    my ( $self, $name ) = @_;

    return $self->nodetype_titles->{$name};


}


=head2 nodetype_by_id

Takes one argument which is the node_id of the nodetype.

Returns the nodetype node that corresponds to it.

=cut

sub nodetype_by_id {

    my ( $self, $id ) = @_;

    return $self->nodetype_ids->{$id};

}

=head2  register_type_module

Takes two arguments.

The first is the package name to which the nodetype relates.

The second is the nodetype node being registered.

Returns the nodetype node.

=cut

sub register_type_module {


    my ( $self, $key, $node ) = @_;

    $self->nodetype_ids->{ $node->{node_id} } = $node if defined $node->{node_id};
    $self->nodetype_titles->{ $node->{title} } = $node if $node->{title};
    return $self->nodetype_modules->{ $key } = $node;


}

=head2  purge_register

Nukes the register.

=cut

sub purge_register {
    my $self = shift;
    $self->nodetype_modules( {} );
    $self->nodetype_ids( {} );
    $self->nodetype_titles( {} );
}

1;
