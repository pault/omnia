#!/usr/bin/perl -w

BEGIN
{
	chdir 't' if -d 't';
	use lib '..', 'blib/lib', 'lib';
}

use Test::More 'no_plan';
use Test::MockObject;
my $mock = Test::MockObject->new();
$mock->fake_module( 'Everything::Node::nodeball', import => sub {} );

use_ok( 'Everything::Node::theme' );
ok( Everything::Node::theme->isa( 'Everything::Node::nodeball' ),
	'Everything::Node::theme should extend Everything::Node::nodeball' );
