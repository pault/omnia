#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 6;

use_ok('Everything::Node::htmlpage');
my $node = FakeNode->new();

$node->{_subs}{SUPER} = [ ( 1 .. 5 ) ];
$node->{parent_container} = 1;

ok(
	Everything::Node::htmlpage::insert( $node, 'user' ),
	'insert() should call SUPER() when finished'
);

$node->{parent_container} = 0;
$node->{DB}               = $node;
$node->{_subs}{getNode} = [ undef, 'general' ];
$node->{_calls} = [];

ok(
	Everything::Node::htmlpage::insert( $node, 'user2' ),
	'... should work without a parent container'
);

is(
	join( ' ', @{ shift @{ $node->{_calls} } } ),
	'getNode general nodelet container container',
	'... should look for general nodelet container lacking parent container'
);
is( $node->{parent_container}, 0, '... using 0 as parent if no gnc found' );

Everything::Node::htmlpage::insert($node);
is( $node->{parent_container}, 'general', '... using gnc, if found' );
