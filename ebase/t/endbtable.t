#!/usr/bin/perl -w

use strict;

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use vars qw( $errors );

use FakeNode;
use Test::More tests => 14;

use_ok( 'Everything::Node::dbtable' );

my $node = FakeNode->new();

# insert()
local *insert = \&Everything::Node::dbtable::insert;
$node->{title} = 'a' x 62;
$node->{DB} = $node;

ok( ! insert($node), 'insert() should fail if node name exceeds 61 characters');
like( $errors, qr/exceed 61/, '.. and should log error' );

$node->{title} = 'a b';
ok( ! insert($node), '... should fail if title contains non-word characters' );
like( $errors, qr/invalid characters/, '.. and should log error' );

$node->{_subs}{SUPER} = [ -1, 0, 1 ];
$node->{title} = 'afin3tit1e';

is( insert($node), -1, '... should return result of SUPER() call' );
is( join(' ', @{ pop @{ $node->{_calls} } }), 'SUPER', 
	'... and should not call createNodeTable() if SUPER() fails' );

insert($node);
is( join(' ', @{ pop @{ $node->{_calls} } }), 'SUPER', 
	'... or if SUPER() returns an invalid node_id' );
is( insert($node), 1, '... should return node_id if insert() succeeds' );
is( join(' ', @{ pop @{ $node->{_calls} } }), 'createNodeTable afin3tit1e', 
	'... and should call createNodeTable() if it succeeds' );

# nuke()
local *nuke = \&Everything::Node::dbtable::nuke;
$node->{_subs}{SUPER} = [ -1, 0, 1 ];
is( nuke($node), -1, 'nuke() should return result of SUPER() call' );
is( join(' ', @{ pop @{ $node->{_calls} } }), 'SUPER', 
	'... and should not call dropNodeTable() if SUPER() fails' );

nuke($node);
is( join(' ', @{ pop @{ $node->{_calls} } }), 'SUPER', 
	'... or if SUPER() returns an invalid node_id' );
nuke($node);
is( join(' ', @{ pop @{ $node->{_calls} } }), 'dropNodeTable afin3tit1e', 
	'... but should call dropNodeTable() if it succeeds' );


package Everything;

sub logErrors {
	$main::errors = shift;
}
