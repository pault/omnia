#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';

	# temporarily avoid sub redefined warnings
	$INC{ 'Everything.pm' } = 1;
}

use Test::More tests => 1;

my $package = 'Everything::NodeBase';

use_ok( $package );

