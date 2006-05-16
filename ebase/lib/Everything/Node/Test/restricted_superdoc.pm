package Everything::Node::Test::restricted_superdoc;

use strict;
use warnings;

use base 'Everything::Node::Test::superdoc';

use Test::More;

sub test_extends :Test( +1 )
{
	my $self  = shift;
	my $class = $self->node_class();

	ok( $class->isa( 'Everything::Node::superdoc' ),
		'restricted_superdoc should extend superdoc' );

	$self->SUPER();
}

1;
