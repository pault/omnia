package Everything::Node::Test::themesetting;

use strict;
use warnings;

use base 'Everything::Node::Test::setting';

use SUPER;
use Test::More;
*Everything::Node::themesetting::SUPER = \&UNIVERSAL::SUPER;

sub test_extends :Test( +1 )
{
	my $self   = shift;
	my $module = $self->node_class();

	ok( $module->isa( 'Everything::Node::setting' ),
		'theme should extend setting' );
	$self->SUPER();
}

sub test_dbtables :Test( 2 )
{
	my $self   = shift;
	my $module = $self->node_class();

	can_ok( $module, 'dbtables' );

	my @tables = $module->dbtables();
	is_deeply( \@tables, [qw( themesetting setting node )],
		'dbtables() should return node tables' );
}
