#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 6;

use_ok( 'Everything::Node::workspace' );

my $node = FakeNode->new();
$node->{_subs}{hasAccess} = [ undef, 1 ];
ok( !Everything::Node::workspace::nuke($node, 'user'),
	'nuke() should return false unless user has delete permission' );
is( join(' ', @{ pop( @{ $node->{_calls} } )}), 'hasAccess user d',
	'... and should call hasAccess to prove it' );

# and add in data for further calls
$node->{DB} = $node;
$node->{node_id} = 'node_id';
$node->{_subs}{SUPER} = [ 1 ];
ok( Everything::Node::workspace::nuke($node, 'user2'),
	'... and true if user does' );

# remove the hasAccess() call
shift @{ $node->{_calls} };
is( join(' ', @{ shift( @{ $node->{_calls} } )}), 
	'sqlDelete revision inside_workspace=node_id',
	'... calling sqlDelete to remove revision' );
is( join(' ', @{ shift( @{ $node->{_calls} } )}), 'SUPER',
	'... and calling SUPER to handle deletion' );
