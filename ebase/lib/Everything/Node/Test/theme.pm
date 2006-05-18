package Everything::Node::Test::theme;

use strict;
use warnings;

use base 'Everything::Node::Test::nodeball';

use Test::More;

sub test_extends :Test( +1 )
{
	my $self  = shift;
	my $class = $self->node_class();

	ok( $class->isa( 'Everything::Node::nodeball' ),
		'theme should extend nodeball' );

	$self->SUPER();
}

sub test_insert_access :Test( 1 )
{
	local $TODO = 'Make nodegroup contain the setting node';
	ok( 0, 'nodegroup cannot call setting methods as functions' );
}

sub test_insert_restrictions :Test( 1 )
{
	local $TODO = 'Make nodegroup contain the setting node';
	ok( 0, 'nodegroup cannot call setting methods as functions' );
}

sub test_insert_restrict_dupes :Test( 1 )
{
	local $TODO = 'Make nodegroup contain the setting node';
	ok( 0, 'nodegroup cannot call setting methods as functions' );
}

sub test_apply_xml_fix_no_fixby_node :Test( 1 )
{
	local $TODO = 'Make nodegroup contain the setting node';
	ok( 0, 'nodegroup cannot call setting methods as functions' );
}

1;
