#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use vars qw( $AUTOLOAD $errors );

use Test::MockObject;
use Test::More tests => 25;

my $package = 'Everything::NodeCache';

use_ok($package) or diag "Compile error\n", exit;

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "${package}::$AUTOLOAD";
	if ( defined &{$sub} )
	{
		*{$AUTOLOAD} = \&{$sub};
		goto &{$sub};
	}
}

my $mock = Test::MockObject->new();

can_ok( $package, 'isSameVersion' );
is( isSameVersion(), undef,
	'isSameVersion() should return undef without node' );

$mock->{version}{12}      = 1;
$mock->{verified}{11}     = 1;
$mock->{typeVerified}{10} = 1;

my $node = {
	type    => { node_id => 10 },
	node_id => 11,
};

$node->{type}{node_id} = 11;
ok( isSameVersion( $mock, $node ), '... true if node type is verified' );

$node->{node_id} = 11;
ok( isSameVersion( $mock, $node ), '... true if node id is verified' );

$node->{node_id} = 13;
ok( !isSameVersion( $mock, $node ),
	'... false unless node version is verified' );

$node->{node_id} = 12;
$mock->set_series( getGlobalVersion => undef, 2, 1 );
ok( !isSameVersion( $mock, $node ),
	'... false unless node has global version' );
ok( !isSameVersion( $mock, $node ), '... false unless global version matches' );
ok( isSameVersion( $mock, $node ), '... true if global version matches' );
ok( $mock->{verified}{12}, '... setting verified flag' );

#stubbing out possible tests:

can_ok( $package, 'setCacheSize' );
can_ok( $package, 'getCacheSize' );
can_ok( $package, 'cacheNode' );
can_ok( $package, 'removeNode' );
can_ok( $package, 'getCachedNodeById' );
can_ok( $package, 'getCachedNodeByName' );
can_ok( $package, 'dumpCache' );
can_ok( $package, 'flushCache' );
can_ok( $package, 'flushCacheGlobal' );
can_ok( $package, 'purgeCache' );
can_ok( $package, 'removeNodeFromHash' );
can_ok( $package, 'getGlobalVersion' );
can_ok( $package, 'incrementGlobalVersion' );
can_ok( $package, 'resetCache' );
can_ok( $package, 'cacheMethod' );
