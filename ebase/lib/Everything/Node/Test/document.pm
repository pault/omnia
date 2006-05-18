package Everything::Node::Test::document;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use Test::More;

sub test_dbtables :Test( 2 )
{
	my $self  = shift;
	my $class = $self->node_class();
	can_ok( $class, 'dbtables' );
	my @tables = $class->dbtables();
	is_deeply( \@tables, [qw( document node )],
		'dbtables() should return node tables' );
}

1;
