#!/usr/bin/perl

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use Test::More tests => 6;

my $module = 'Everything::Node::usergroup';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::nodegroup' ),
	'usergroup should extend nodegroup' );

can_ok( $module, 'dbtables' );
my @tables = $module->dbtables();
is_deeply( \@tables, [qw( node )],
	'dbtables() should return node tables' );

ok(
	!Everything::Node::usergroup::conflictsWith(),
	'conflictsWith() should return false'
);

ok(
	!Everything::Node::usergroup::updateFromImport(),
	'updateFromImport() should return false'
);
