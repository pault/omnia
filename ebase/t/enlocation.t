#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 15;

use_ok( 'Everything::Node::location' );
my $node = FakeNode->new();

# nuke
local *nuke = \&Everything::Node::location::nuke;

$node->{_subs}{SUPER} = [ -1, 0, 1 ];
$node->{DB} = $node;
$node->{node_id} = 'node_id';
$node->{loc_location} = 'loc_location';

is( nuke($node), -1, 'nuke() should return result of SUPER() call' );
is( $node->{_calls}->[-1][0], 'SUPER', 
	'... should not call sqlUpdate() if SUPER() call fails' );

nuke($node);
is( $node->{_calls}->[-1][0], 'SUPER', 
	'... or if SUPER() returns invalid node_id' );

nuke($node);
my $call = $node->{_calls}->[-1];
is( $call->[0], 'sqlUpdate', 
	'... should call sqlUpdate() if SUPER() call succeeds' );
is( $call->[1], 'node', '... updating node table' );
is( $call->[2]{loc_location}, 'loc_location', 'updating loc_location' );
is( $call->[3], 'loc_location=node_id', '... matching node_id' );

# listNodes()
*listNodes = \&Everything::Node::location::listNodes;
# use sqlSelectMany to find all nodes in this location
# -if that succeeds
#	loop through results with fetchrow()
#	call getRef on id if full flag is passed
#	save node id
#	call finish()
# return array ref of results
$node->{_calls} = [];
$node->{node_id} = 'node_id';
$node->{_subs} = {
	fetchrow		=> [ 1, 2, undef, 1 ],
	sqlSelectMany	=> [ undef, $node, $node ],
};

is( scalar @{ listNodes($node) }, 0, 
	'listNodes() should return nothing with no nodes in location' );
like( join(' ', @{ $node->{_calls}[0] }), qr/sqlSelectMany.+location=node_id/,
	'... should call sqlSelectMany() to find its nodes' );

use Data::Dumper;
$node->{_calls} = [];
my $nodes = listNodes($node);
is( scalar @$nodes, 2, '... should return array ref of found nodes' );
is( join('', @$nodes), '12', '... and the right nodes' );
ok( !( grep { $_->[0] eq 'getRef' } @{ $node->{_calls} }), 
	'... but should not call getRef on nodes without full flag' );

$node->{_calls} = [];
listNodes($node, 1);
ok( ( grep { $_->[0] eq 'getRef' } @{ $node->{_calls} }), 
	'... and should not call getRef on nodes without full flag' );
is( $node->{_calls}[-1][0], 'finish', '... and should finish() cursor' );
