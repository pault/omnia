#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 5;

use_ok('Everything::Node::nodelet');

my $node = FakeNode->new();
$node->{_subs} = {
	SUPER => [ ( 1 .. 5 ) ],
	getNode => [ { node_id => 1 }, undef ],
};
$node->{DB}               = $node;
$node->{parent_container} = 8;

is( Everything::Node::nodelet::insert($node),
	1, 'insert() should call SUPER() at end' );
is(
	join( ' ', @{ shift @{ $node->{_calls} } } ),
	'getNode general nodelet container container',
	'... should get general nodelet container, if possible'
);
is( $node->{parent_container}, 1, '... setting parent_container to gnc if so' );

Everything::Node::nodelet::insert($node);
is( $node->{parent_container}, 0, '... and to 0 if not' );
