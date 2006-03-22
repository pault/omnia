#!/usr/bin/perl

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use Test::More tests => 4;

my $module = 'Everything::Node::container';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::node' ), 'container should extend node' );

can_ok( $module, 'dbtables' );
my @tables = $module->dbtables();
is_deeply( \@tables, [qw( container node )],
	'dbtables() should return node tables' );
