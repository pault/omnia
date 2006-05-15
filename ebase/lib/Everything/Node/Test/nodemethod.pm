package Everything::Node::Test::nodemethod;

use strict;
use warnings;

use base 'Everything::Node::Test::node';
use Test::More;

sub test_dbtables :Test( 2 )
{
	my $self  = shift;
	my $class  = $self->node_class();

	can_ok( $class, 'dbtables' );

	my @tables = $class->dbtables();
	is_deeply( \@tables, [qw( nodemethod node )],
		'dbtables() should return node tables' );
}

sub test_get_identifying_fields :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};

	is_deeply( $node->getIdentifyingFields(), [ 'supports_nodetype' ],
		'getIdentifyingFields() should report "supports_nodetype"' );
}

1;
