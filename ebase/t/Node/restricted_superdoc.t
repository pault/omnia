#!/usr/bin/perl

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use Test::More tests => 2;

my $module = 'Everything::Node::restricted_superdoc';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::superdoc' ),
	'restricted_superdoc should extend superdoc' );
