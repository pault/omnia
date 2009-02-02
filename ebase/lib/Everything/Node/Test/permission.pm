package Everything::Node::Test::permission;

use strict;
use warnings;

use base 'Everything::Node::Test::htmlcode';

use Test::More;
use SUPER;

sub test_extends :Test( +1 )
{
	my $self  = shift;
	my $class = $self->node_class();

	ok( $class->isa( 'Everything::Node::htmlcode' ),
		'permission should extend htmlcode' );

	$self->SUPER();
}

1;
