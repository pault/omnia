#!/usr/bin/perl

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use FakeNode;
use Test::More tests => 9;

my $module = 'Everything::Node::workspace';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::setting' ),
	'workspace should extend setting' );

can_ok( $module, 'dbtables' );
my @tables = $module->dbtables();
is_deeply( \@tables, [qw( setting node )],
	'dbtables() should return node tables' );

my $node = FakeNode->new();
$node->{_subs}{hasAccess} = [ undef, 1 ];
ok(
	!Everything::Node::workspace::nuke( $node, 'user' ),
	'nuke() should return false unless user has delete permission'
);
is(
	join( ' ', @{ pop( @{ $node->{_calls} } ) } ),
	'hasAccess user d',
	'... and should call hasAccess to prove it'
);

# and add in data for further calls
$node->{DB}           = $node;
$node->{node_id}      = 'node_id';
$node->{_subs}{SUPER} = [1];
ok( Everything::Node::workspace::nuke( $node, 'user2' ),
	'... and true if user does' );

# remove the hasAccess() call
shift @{ $node->{_calls} };
is(
	join( ' ', @{ shift( @{ $node->{_calls} } ) } ),
	'sqlDelete revision inside_workspace=node_id',
	'... calling sqlDelete to remove revision'
);
is( join( ' ', @{ shift( @{ $node->{_calls} } ) } ),
	'SUPER', '... and calling SUPER to handle deletion' );
