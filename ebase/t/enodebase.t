#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';

	# temporarily avoid sub redefined warnings
	$INC{ 'Everything.pm' } = 1;
}

use Test::More tests => 6;

my $package = 'Everything::NodeBase';

use_ok( $package );

can_ok( $package, 'genTableName' );
is( $package->genTableName( 'foo' ), 'foo',
	'genTableName() should return first arg' );

can_ok( $package, 'genLimitString' );
is( $package->genLimitString( 10, 20 ), 'LIMIT 10, 20',
	'genLimitString() should return a valid limit' );
is( $package->genLimitString( undef, 20 ), 'LIMIT 0, 20',
	'... defaulting to an offset of zero' );

