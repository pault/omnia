#!/usr/bin/perl

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use Test::More tests => 2;

my $module = 'Everything::Node::javascript';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::node' ), 'javascript should extend node' );
