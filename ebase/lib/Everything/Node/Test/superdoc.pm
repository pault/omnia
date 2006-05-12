package Everything::Node::Test::superdoc;

use strict;
use warnings;

use base 'Everything::Node::Test::document';

use SUPER;
use Test::More;

*Everything::Node::document::SUPER = \&UNIVERSAL::SUPER;

sub test_dbtables :Test( 2 )
{
	my $self  = shift;
	my $class = $self->node_class();
	can_ok( $class, 'dbtables' );
	my @tables = $class->dbtables();
	is_deeply( \@tables, [qw( document node )],
		'dbtables() should return node tables' );
}

1;
