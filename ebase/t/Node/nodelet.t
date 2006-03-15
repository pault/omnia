#!/usr/bin/perl

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use FakeNode;
use Test::More tests => 6;

my $module = 'Everything::Node::nodelet';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::node' ), 'nodelet should extend node' );

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
