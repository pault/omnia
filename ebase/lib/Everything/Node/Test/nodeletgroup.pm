package Everything::Node::Test::nodeletgroup;

use strict;
use warnings;

use base 'Everything::Node::Test::nodegroup';

use Test::More;

sub test_extends :Test( +1 )
{
	my $self  = shift;
	my $class = $self->node_class();
	ok( $class->isa( 'Everything::Node::nodegroup' ),
		'nodeletgroup should extend nodegroup' );

	$self->SUPER();
}

1;
