#!/usr/bin/perl

use strict;
use warnings;

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use vars qw( $errors $AUTOLOAD );

use FakeNode;
use Test::More tests => 19;

my $module = 'Everything::Node::dbtable';
use_ok( $module ) or exit;

ok( $module->isa( 'Everything::Node::node' ), 'dbtable should extend node' );

can_ok( $module, 'dbtables' );
my @tables = $module->dbtables();
is_deeply( \@tables, [ 'node' ], 'dbtables() should return node tables' );

local *Everything::logErrors;

*Everything::logErrors = sub
{
	$main::errors = shift;
};

my $node = FakeNode->new();

# insert()
$node->{title} = 'foo';
$node->{_subs} = {
	SUPER => [ -1, 0, 1 ],
	restrictTitle => [ 0, (1) x 4 ],
};
$node->{DB} = $node;

$node->{title} = 'afin3tit1e';

$node->{_calls} = [];
is( insert($node), -1, '... should return result of SUPER() call' );
is( join( ' ', @{ $node->{_calls}[0] } ),
	'SUPER', '... and should not call createNodeTable() if SUPER() fails' );

$node->{_calls} = [];
insert($node);
is( scalar @{ $node->{_calls} },
	1, '... or if SUPER() returns an invalid node_id' );
is( insert($node), 1, '... should return node_id if insert() succeeds' );
is(
	join( ' ', @{ pop @{ $node->{_calls} } } ),
	'createNodeTable afin3tit1e',
	'... and should call createNodeTable() if it succeeds'
);

# nuke()
$node->{_subs}{SUPER} = [ -1, 0, 1 ];
is( nuke($node), -1, 'nuke() should return result of SUPER() call' );
is( join( ' ', @{ pop @{ $node->{_calls} } } ),
	'SUPER', '... and should not call dropNodeTable() if SUPER() fails' );

nuke($node);
is( join( ' ', @{ pop @{ $node->{_calls} } } ),
	'SUPER', '... or if SUPER() returns an invalid node_id' );
nuke($node);
is(
	join( ' ', @{ pop @{ $node->{_calls} } } ),
	'dropNodeTable afin3tit1e',
	'... but should call dropNodeTable() if it succeeds'
);

# restrictTitle()
ok( !restrictTitle( { foo => 1 } ),
	'restrictTitle() with no title field should return false' );
ok(
	!restrictTitle( { title => 'longblob' } ),
	'... or if title is a db reserved word'
);

ok(
	!restrictTitle( { title => 'x' x 62 } ),
	'... or if title exceeds 61 characters'
);
like( $errors, qr/exceed 61/, '.. and should log error' );

ok( !restrictTitle( { title => 'a b' } ),
	'... should fail if title contains non-word characters' );
like( $errors, qr/invalid characters/, '.. and should log error' );

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::Node::dbtable::$AUTOLOAD";
	if ( defined &{$sub} )
	{
		*{$AUTOLOAD} = \&{$sub};
		goto &{$sub};
	}
}
