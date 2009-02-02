package Everything::Node::Test::mail;

use strict;
use warnings;

use base 'Everything::Node::Test::document';

use Test::More;
use SUPER;

sub test_dbtables :Test( 2 )
{
	my $self  = shift;
	my $class = $self->node_class();

	can_ok( $class, 'dbtables' );

	my @tables = $class->dbtables();
	is_deeply( \@tables, [qw( mail document node )],
		'dbtables() should return node tables' );
}

sub test_extends :Test( +1 )
{
	my $self  = shift;
	my $class = $self->node_class();

	ok( $class->isa( 'Everything::Node::document' ),
		'mail should extend document' );

	$self->SUPER();
}

1;
