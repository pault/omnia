#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use Test::More tests => 3;

use_ok( 'Everything::Node::usergroup' );

ok( !Everything::Node::usergroup::conflictsWith(), 
	'conflictsWith() should return false' );

ok( !Everything::Node::usergroup::updateFromImport(), 
	'updateFromImport() should return false' );
