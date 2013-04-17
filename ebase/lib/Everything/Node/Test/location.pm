package Everything::Node::Test::location;

use strict;
use warnings;

use base 'Everything::Node::Test::node';

use Test::More;
use SUPER;

sub test_nuke :Test( +8 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$db->set_true( 'sqlUpdate' );
	$self->SUPER();

	return "Code moved to DB/Node/location.pm";
	$node->set_series( super => -1, 0, 1 );
	$db->clear();

	$node->{node_id}      = 'node_id';
	$node->{loc_location} = 'loc_location';

	is( $node->nuke( 'user' ), -1,
		'nuke() should return result of SUPER() call' );

	my ($method, $args) = $node->next_call();
	is( $args->[1], 'user', '... passing user to parent method' );

	isnt( $db->next_call(), 'sqlUpdate', 
		'... not calling sqlUpdate() if SUPER() call fails' );

	$node->nuke( 'user' );
	isnt( $db->next_call(), 'sqlUpdate',
		'... or if SUPER() returns invalid node_id' );

	$node->nuke( 'user');
	($method, $args) = $db->next_call();

	is( $method, 'sqlUpdate',
		'... but should call sqlUpdate() if SUPER() call succeeds' );
	is( $args->[1], 'node', '... updating node table' );
	is( $args->[2]{loc_location}, 'loc_location', 'updating loc_location' );
	is( $args->[3], 'loc_location=node_id', '... matching node_id' );
}

sub test_list_nodes :Test( 5 )
{
	my $self = shift;
	my $node = $self->{node};

	$node->set_always( listNodesWhere => 'lnw' );

	my $result          = $node->listNodes( 'full_flag' );
	my ($method, $args) = $node->next_call();

	is( $method, 'listNodesWhere', 'listNodes() should call listNodesWhere()' );
	is( $args->[1], '',            '... with no WHERE clause' );
	is( $args->[2], '',            '... with no ORDER clause' );
	is( $args->[3], 'full_flag',   '... passing the full flag' );
	is( $result, 'lnw',            '... and returning the results' );
}


sub test_list_nodes_where :Test( 11 )
{
	my $self = shift;
	my $node = $self->{node};
	my $db   = $self->{mock_db};

	$db->set_false( 'sqlSelectMany' );
	$node->{node_id} = 'node_id';

	$node->listNodesWhere( 'where', 'an order' );
	my ($method, $args) = $db->next_call();

	is( $method, 'sqlSelectMany', 'listNodesWhere() should fetch nodes' );
	like( $args->[3], qr/^where loc_loca/, '... adding passed where clause' );
	is( $args->[4], 'an order', '... using passed order clause' );

	$node->listNodesWhere();
	($method, $args) = $db->next_call();

	like( $args->[3], qr/^ loc_loca/,
		'... but should use default where clause' );
	is( $args->[4], 'order by title', '... and default order clause' );

	$db->set_series( fetchrow => 1, 2, undef, 1 )
	   ->set_series( sqlSelectMany => undef, $db, $db )
	   ->set_true( qw( getRef finish ));

	is( @{ $node->listNodesWhere( '', '', '') }, 0,
		'... returning empty array ref without nodes in location' );

	my $nodes = $node->listNodesWhere( '', '' );
	is( @$nodes, 2, '... returning array ref of found nodes' );
	is( join( '', @$nodes ), '12', '... and the right nodes' );
	ok( !( grep { $_ eq 'getRef' } map { scalar $db->next_call() } 1 .. 5 ),
		'... but should not call getRef on nodes without full flag' );

	$node->listNodesWhere( '', '', 1 );
	ok( ( grep { $_ eq 'getRef' } map { scalar $db->next_call() } 1 .. 5 ),
		'... and should call getRef on nodes with full flag' );

	is( $db->next_call(), 'finish', '... and should finish() cursor' );
}

1;
