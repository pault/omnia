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
