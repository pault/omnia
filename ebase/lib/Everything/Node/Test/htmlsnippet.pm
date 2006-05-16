package Everything::Node::Test::htmlsnippet;

use strict;
use warnings;

use base 'Everything::Node::Test::htmlcode';
use Test::More;

sub test_extends :Test( +1 )
{
	my $self  = shift;
	my $class = $self->node_class();
	ok( $class->isa( 'Everything::Node::htmlcode' ),
		'htmlsnippet should extend htmlcode' );
	$self->SUPER();
}

1;
