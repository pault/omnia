#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

# to catch use() in module
use vars qw( $caller );
$INC{'Everything/Node.pm'} = 1;

use FakeNode;
use Test::More tests => 9;

use_ok( 'Everything::Node::nodemethod' );

is( $caller, 'Everything::Node::nodemethod', 
	'Everything::Node::nodemethod should use Everything::Node' );

is( Everything::Node::nodemethod::getIdentifyingFields()->[0],
	'supports_nodetype', 
	'getIdentifyingFields() should report "supports_nodetype"');

my $node = FakeNode->new();
$node->{DB}{cache} = $node;
$node->{type} = 'type';

SKIP: {
	my @subs = (
		\&Everything::Node::nodemethod::insert,
		\&Everything::Node::nodemethod::update,
		\&Everything::Node::nodemethod::nuke 
	);

	skip('insert(), update(), nuke() not defined', 6) unless 
		grep { defined &$_ } @subs;

	foreach my $method ( @subs ) {
	
		$node->{_calls} = [];
		$method->($node);
		is( $node->{_calls}[0][0], 'SUPER', 
			'... other methods should call SUPER()');
		is( join(' ', @{ $node->{_calls}[1] }), 'incrementGlobalVersion type',
			'... and should call incrementGlobalVersion() with type' );
	}
}

package Everything::Node;

sub import {
	$main::caller = caller();
}
