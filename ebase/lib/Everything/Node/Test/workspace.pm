package Everything::Node::Test::workspace;

use strict;
use warnings;

use base 'Everything::Node::Test::setting';

use Test::More;

sub test_extends :Test( +1 )
{
	my $self  = shift;
	my $class = $self->node_class();

	ok( $class->isa( 'Everything::Node::setting' ),
		'workspace should extend setting' );

	$self->SUPER();
}

sub test_nuke :Test( 7 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->set_series( super => 0, 1 );
	$db->set_true( 'sqlDelete' );

	my $result = $node->nuke( 'user' );
	my ($method, $args)    = $node->next_call();
	is( $method, 'super',    'nuke() should call super()' );
	is( $args->[1], 'user', '... with the user' );

	ok( ! $result, '... returning false if it fails' );

	$node->{node_id} = 'my_id';
	ok( $node->nuke( 'user' ), '... and true if it succeeds' );

	($method, $args) = $db->next_call();
	is( $method, 'sqlDelete',   '... so should delete from the database' );
	is( $args->[1], 'revision', '... a revision' );
	is( $args->[2], 'inside_workspace=my_id', '... inside the node workspace' );
}

1;
__END__
