package Everything::Node::Test::opcode;

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
		'opcode should extend htmlcode' );
	$self->SUPER();
}

1;
