#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;

$INC{ 'Everything/Node/nodeball.pm' } = 1;
$Everything::Node::nodeball::VERSION = $Everything::Node::nodeball::VERSION = 1;

use_ok( 'Everything::Node::theme' );
ok(
	Everything::Node::theme->isa('Everything::Node::nodeball'),
	'Everything::Node::theme should extend Everything::Node::nodeball'
);
