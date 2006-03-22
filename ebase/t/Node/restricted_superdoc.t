#!/usr/bin/perl

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use Test::More tests => 4;

my $module = 'Everything::Node::restricted_superdoc';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::superdoc' ),
	'restricted_superdoc should extend superdoc' );

can_ok( $module, 'dbtables' );
my @tables = $module->dbtables();
is_deeply( \@tables, [qw( document node )],
	'dbtables() should return node tables' );
