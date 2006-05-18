package Everything::Node::Test::superdoc;

use strict;
use warnings;

use base 'Everything::Node::Test::document';

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

sub test_extends :Test( +1 )
{
	my $self  = shift;
	my $class = $self->node_class();

	ok( $class->isa( 'Everything::Node::document' ),
		'superdoc should extend document' );

	$self->SUPER();
}

1;
