#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 20;

use_ok('Everything::Node::location');
my $node = FakeNode->new();

# nuke()
$node->{_subs}{SUPER} = [ -1, 0, 1 ];
$node->{DB} = $node;
$node->{node_id}      = 'node_id';
$node->{loc_location} = 'loc_location';

is( nuke($node), -1, 'nuke() should return result of SUPER() call' );
is( $node->{_calls}->[-1][0],
	'SUPER', '... should not call sqlUpdate() if SUPER() call fails' );

nuke($node);
is( $node->{_calls}->[-1][0],
	'SUPER', '... or if SUPER() returns invalid node_id' );

nuke($node);
my $call = $node->{_calls}->[-1];
is( $call->[0], 'sqlUpdate',
	'... should call sqlUpdate() if SUPER() call succeeds' );
is( $call->[1], 'node', '... updating node table' );
is( $call->[2]{loc_location}, 'loc_location', 'updating loc_location' );
is( $call->[3], 'loc_location=node_id', '... matching node_id' );

# listNodes()
$node->{_calls}  = [];
$node->{node_id} = 'node_id';
$node->{_subs}   = {
	fetchrow      => [ 1,     2,     undef, 1 ],
	sqlSelectMany => [ undef, $node, $node ],
};

local *FakeNode::listNodesWhere;
*FakeNode::listNodesWhere = \&Everything::Node::location::listNodesWhere;

is( scalar @{ listNodes($node) },
	0, 'listNodes() should return empty array ref with no nodes in location' );
like(
	join( ' ', @{ $node->{_calls}[0] } ),
	qr/sqlSelectMany.+location='node_id'/,
	'... should call sqlSelectMany() to find its nodes'
);

$node->{_calls} = [];
my $nodes = listNodes($node);
is( scalar @$nodes, 2, '... should return array ref of found nodes' );
is( join( '', @$nodes ), '12', '... and the right nodes' );
ok(
	!( grep { $_->[0] eq 'getRef' } @{ $node->{_calls} } ),
	'... but should not call getRef on nodes without full flag'
);

$node->{_calls} = [];
listNodes( $node, 1 );
ok(
	( grep { $_->[0] eq 'getRef' } @{ $node->{_calls} } ),
	'... and should call getRef on nodes with full flag'
);
is( $node->{_calls}[-1][0], 'finish', '... and should finish() cursor' );

# listNodesWhere()
$node->{_calls} = [];
listNodesWhere( $node, 'where', 'an order' );
$call = $node->{_calls}[0];
is( $call->[0], 'sqlSelectMany', 'listNodesWhere should fetch nodes' );
like( $call->[3], qr/^where loc_loca/, '... adding any passed where clause' );
is( $call->[4], 'an order', '... and using any passed order clause' );

listNodesWhere($node);
$call = $node->{_calls}[1];
like( $call->[3], qr/^ loc_loca/, '... but should use default where clause' );
is( $call->[4], 'order by title', '... and default order clause' );

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::Node::location::$AUTOLOAD";

	if ( defined &{$sub} )
	{
		*{$AUTOLOAD} = \&{$sub};
		goto &{$sub};
	}
}
