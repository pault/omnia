#!/usr/bin/perl

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use Test::More tests => 2;

my $module = 'Everything::Node::symlink';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::node' ), 'theme should extend node' );
