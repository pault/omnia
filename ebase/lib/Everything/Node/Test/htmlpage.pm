package Everything::Node::Test::htmlpage;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use Test::More;

sub test_dbtables
{
	my $self  = shift;
	my $class = $self->node_class();

	can_ok( $class, 'dbtables' );

	my @tables = $class->dbtables();
	is_deeply( \@tables, [qw( htmlpage node )],
		'dbtables() should return node tables' );
}

sub test_insert :Test( +5 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->{parent_container} = 'npc';
	$self->SUPER();

	$node->{DB} = $db;
	delete $node->{parent_container};
	$node->set_true( 'SUPER' );
	$db->set_series( -getNode => undef, 'gnc' );

	$node->insert( 'user' );
	is( $node->{parent_container}, 0,
		'insert() should set node parent container to 0 without it and a GNC' );

	$node->insert( 'user' );
	is( $node->{parent_container}, 'gnc',
		'... but should set it to GNC if that exists' );

	$node->{parent_container} = 'npc';
	$node->insert( 'user' );
	is( $node->{parent_container}, 'npc',
		'... but should not override an existing parent container' );

	my ($method, $args) = $node->next_call();
	is( $method, 'SUPER',   '... and should call SUPER()' );
	is( $args->[1], 'user', '... passing user' );

	$node->clear();
}

sub test_insert_access :Test( +0 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->{parent_container} = 'npc';
	$self->SUPER();
}

sub test_insert_restrictions :Test( +0 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->{parent_container} = 'npc';
	$self->SUPER();
}

sub test_insert_restrict_dupes :Test( +0 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->{parent_container} = 'npc';
	$self->SUPER();
}

1;
