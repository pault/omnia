package Everything::Node::Test::dbtable;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use Test::More;
use SUPER;

sub test_insert :Test( 8 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->{title} = 'foo';
	$node->set_series( super => -1, 0, 1 );
	$db->set_true( 'createNodeTable' );
	
	my $result = $node->insert( 'user' );
	my ($method, $args) = $node->next_call();

	isnt( $db->next_call(), 'createNodeTable',
		'insert() should not create node table unless SUPER() succeeds' );
	is( $result, -1, '... and should return result of SUPER() call' );
	is( $method, 'super', '... so should call SUPER()' );
	is( $args->[1], 'user', '... passing user argument' );

	$result = $node->insert();
	isnt( $db->next_call(), 'createNodeTable',
		'... nor should it create table if SUPER() returns false' );

	$result = $node->insert();
	is( $result, 1, '... but should return node_id if insert succeeds' );

	($method, $args) = $db->next_call();
	is( $method, 'createNodeTable', '... creating table' );
	is( $args->[1], 'foo', '... named after the node' );
}

sub test_insert_access :Test( +0 )
{
	my $self = shift;
	my $db   = $self->{mock_db};
	$db->set_true( -createNodeTable );
	$self->SUPER();
}

sub test_insert_restrict_dupes :Test( +0 )
{
	my $self = shift;
	my $db   = $self->{mock_db};
	$db->set_true( -createNodeTable );
	$self->SUPER();
}

sub test_insert_restrictions :Test( +0 )
{
	my $self = shift;
	my $db   = $self->{mock_db};
	$db->set_true( -createNodeTable );
	$self->SUPER();
}

sub test_nuke :Test( 8 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->{title} = 'foo';
	$node->set_series( super => -1, 0, 1 );
	$db->set_true( 'dropNodeTable' );
	
	my $result = $node->nuke( 'user' );
	my ($method, $args) = $node->next_call();

	isnt( $db->next_call(), 'dropNodeTable',
		'nuke() should not drop node table unless SUPER() succeeds' );
	is( $result, -1, '... and should return result of SUPER() call' );
	is( $method, 'super', '... so should call super()' );
	is( $args->[1], 'user', '... passing user argument' );

	$result = $node->nuke();
	isnt( $db->next_call(), 'dropNodeTable',
		'... nor should it drop table if SUPER() returns false' );

	$result = $node->nuke();
	is( $result, 1, '... but should return node_id if nuke succeeds' );

	($method, $args) = $db->next_call();
	is( $method, 'dropNodeTable', '... dropping table' );
	is( $args->[1], 'foo', '... named after the node' );
}

sub test_restrict_title :Test( 6 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->{title} = 'longblob';
	ok( ! $node->restrictTitle(),
		'restrictTitle() should return false if title is a db reserved word' );
	like( $self->{errors}[0][0], qr/reserved word/, '.. and should log error' );

	$node->{title} = 'x' x 62;
	ok( ! $node->restrictTitle(), '... or if title exceeds 61 characters' );

	like( $self->{errors}[1][0], qr/exceed 61/, '.. and should log error' );
	
	$node->{title} = 'a b';
	ok( ! $node->restrictTitle(),
		'... should fail if title contains non-word characters' );

	like( $self->{errors}[2][0], qr/invalid characters/,
		'.. and should log error' );
}

1;
