#!/usr/bin/perl

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use FakeNode;
use Test::More tests => 12;

my $module = 'Everything::Node::nodemethod';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::node' ), 'nodemethod should extend node' );

ok( $INC{'Everything/Node.pm'},
	'Everything::Node::nodemethod should use Everything::Node'
);

can_ok( $module, 'dbtables' );
my @tables = $module->dbtables();
is_deeply( \@tables, [qw( nodemethod node )],
	'dbtables() should return node tables' );

is( Everything::Node::nodemethod::getIdentifyingFields()->[0],
	'supports_nodetype',
	'getIdentifyingFields() should report "supports_nodetype"' );

my $node = FakeNode->new();
$node->{DB}{cache} = $node;
$node->{type} = 'type';

SKIP:
{
	my @subs = (
		\&Everything::Node::nodemethod::insert,
		\&Everything::Node::nodemethod::update,
		\&Everything::Node::nodemethod::nuke
	);

	skip( 'insert(), update(), nuke() not defined', 6 )
		unless grep { defined &$_ } @subs;

	foreach my $method (@subs)
	{

		$node->{_calls} = [];
		$method->($node);
		is( $node->{_calls}[0][0],
			'SUPER', '... other methods should call SUPER()' );
		is(
			join( ' ', @{ $node->{_calls}[1] } ),
			'incrementGlobalVersion type',
			'... and should call incrementGlobalVersion() with type'
		);
	}
}
