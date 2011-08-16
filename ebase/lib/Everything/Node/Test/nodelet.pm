package Everything::Node::Test::nodelet;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use Test::More;
use SUPER;

sub test_dbtables :Test( 2 )
{
	my $self   = shift;
	my $module = $self->node_class();
	can_ok( $module, 'dbtables' );
	my @tables = $module->dbtables();
	is_deeply( \@tables, [qw( nodelet node )],
		'dbtables() should return node tables' );
}

sub test_insert :Test( 4 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$node->set_always( super => 'super' );
	$db->set_series( getNode => { node_id => 1 }, undef );
	$node->{parent_container} = 8;

	is( $node->insert( 'user' ), 'super',
		'insert() should return result of SUPER() call' );

	my ($method, $args) = $node->next_call();
	is( $args->[1], 'user', '... passing the user' );

	is( $node->{parent_container}, 1,
		'... setting node parent_container to GNC id if it exists' );

	$node->insert( 'user' );
	is( $node->{parent_container}, 0, '... and to 0 if not' );
}

sub test_insert_access :Test( +0 )
{
	my $self = shift;
	my $db   = $self->{mock_db};
	$db->set_false( -getNode );
	$self->SUPER();
}

sub test_insert_restrict_dupes :Test( +0 )
{
	my $self = shift;
	my $db   = $self->{mock_db};
	$db->set_false( -getNode );
	$self->SUPER();
}

sub test_insert_restrictions :Test( +0 )
{
	my $self = shift;
	my $db   = $self->{mock_db};
	$db->set_false( -getNode );
	$self->SUPER();
}

sub test_get_node_keys :Test( +2 )
{
	my $self = shift;
	my $node = $self->{node};

	$self->SUPER();

	no strict 'refs';
	local *{ $self->node_class . '::super' } = sub { +{node_id => 10, nltext => 'nltext' } };
	use strict 'refs';

	my $result = $node->getNodeKeys( 0 );
	is( $result->{nltext}, 'nltext',
		'getNodeKeys() should not remove nltext unlesss exporting' );

	$result    = $node->getNodeKeys( 1 );
	is( $result->{nltext}, undef, '... but should really remove it then' );
}


sub test_get_node_keep_keys : Test( +2 ) {
    my $self = shift;
    $self->SUPER::test_get_node_keep_keys;

    my $node = $self->{node};

    is ( $node->getNodeKeepKeys->{lastupdate}, 1, '...lastupdate is a key not to be changed.' );
    is ( $node->getNodeKeepKeys->{nltext}, 1, '...nltext is a key not to be changed.' );

}

1;
