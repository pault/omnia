package Everything::Node::Test::usergroup;

use strict;
use warnings;

use base 'Everything::Node::Test::nodegroup';
use Test::More;

sub test_extends :Test( +1 )
{
	my $self  = shift;
	my $class = $self->node_class();

	ok( $class->isa( 'Everything::Node::nodegroup' ),
		'usergroup should extend nodegroup' );

	$self->SUPER();
}

sub test_conflicts_with :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};
	ok( ! $node->conflictsWith(), 'conflictsWith() should return false' );
}

sub test_update_from_import :Test( 1 )
{
	my $self = shift;
	my $node = $self->{node};
	ok( ! $node->updateFromImport(), 'updateFromImport() should return false' );
}

1;
