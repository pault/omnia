package Everything::Node::Test::htmlcode;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use Test::More;
use SUPER;

*Everything::Node::htmlcode::SUPER = \&UNIVERSAL::SUPER;

sub node_class { 'Everything::Node::htmlcode' }

sub test_dbtables :Test( 2 )
{
	my $self  = shift;
	my $class = $self->node_class();
	can_ok( $class, 'dbtables' );
	my @tables = $class->dbtables();
	is_deeply( \@tables, [qw( htmlcode node )],
		'dbtables() should return node tables' );
}

1;

sub test_restrict_title :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};

	ok( ! $node->restrictTitle(),
		'restrictTitle() should return false with no title' );

	$node->{title} = 'bad title';
	ok( ! $node->restrictTitle(),
		'... should return false if title contains a space' );

	like( $self->{errors}[0][0], qr/htmlcode.+invalid characters/,
		'... logging an error' );

	$node->{title} = join( '', ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 ) );
	ok( $node->restrictTitle(),
		'... returning true if title contains only alphanumeric characters' );
}
