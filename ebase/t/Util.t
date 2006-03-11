#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	use lib '../blib/lib', '../lib', '..';
}

use Test::More tests => 7;

use_ok('Everything::Util');

can_ok( 'main', 'escape' );
my $encoded = escape('abc|@# _123');
like( $encoded, qr/^abc.+_123$/, 'escape() should not modify alphanumerics' );
my @encs = $encoded =~ m/%([a-fA-F\d]{2})/g;
is( scalar @encs, 4, '... should encode all nonalphanumerics in string' );
is( join( '', map { chr( hex($_) ) } @encs ),
	'|@# ', '... using ord() and hex()' );

can_ok( 'main', 'unescape' );
is( unescape($encoded), 'abc|@# _123', 'unescape() should reverse escape()' );
