package Everything::Node::Test::setting;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use Test::More;
use SUPER;

sub test_extends :Test( +1 )
{
	my $self   = shift;
	my $module = $self->node_class();
	ok( $module->isa( 'Everything::Node::node' ),
		'setting should extend node' );
	$self->SUPER();
}

sub test_dbtables :Test( 2 )
{
	my $self   = shift;
	my $module = $self->node_class();

	can_ok( $module, 'dbtables' );
	my @tables = $module->dbtables();
	is_deeply( \@tables, [qw( setting node )],
		'dbtables() should return node tables' );
}

sub test_get_vars :Test( 2 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( getHash => { foo => 'bar' } );

	is_deeply( $node->getVars($node), { foo => 'bar' },
		'getVars() should call getHash() on node' );

	is( ( $node->next_call() )[1]->[1], 'vars', '... with "vars" argument' );
}

sub test_set_vars :Test( 2 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_true( 'setHash' );
	$node->setVars( { my => 'vars' } );

	my ($method, $args) = $node->next_call();
	is( $method, 'setHash', 'setVars() should call setHash()' );
	is_deeply( $args->[1], { my => 'vars' }, '... with hash arguments' );
}

sub test_has_vars :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};
	ok( $node->hasVars(), 'hasVars() should return true' );
}

sub test_get_node_keep_keys :Test( +1 )
{
	my $self   = shift;
	my $node   = $self->{node};
	my $result = $node->getNodeKeepKeys();
	is( $result->{vars}, 1, '... and should set "vars" to true in results' );
	$self->SUPER();
}

sub test_update_from_import :Test( +2 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( -SUPER   => 10 )
	     ->set_series( -getVars => { a => 1, b => 2 }, $node )
		 ->set_true( '-setVars' );

	my $newnode = Test::MockObject->new( { foo => 1, bar => 2, baz => 3 } );

	$newnode->set_series( -getVars => { a => 1, b => 2 }, $node );
	$self->{newnode} = $newnode;

	$self->SUPER;

	$newnode->set_series( -getVars => { a => 100, b => 200 }, $node );
	$node->set_true( 'setVars' );
	$node->set_always( -getVars => { a => 1, b => 2 } );

	$node->updateFromImport( $newnode, $node, $node );

	is( $node->next_call(), 'setVars', '... and should call setVars()' );
	my $vars = $node->getVars;
	is( join( '', @$vars{ 'a', 'b' } ), '12',
		'... and merging keys from new node' );
}

1;
