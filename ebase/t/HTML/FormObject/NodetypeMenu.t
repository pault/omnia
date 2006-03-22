#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

package Everything::HTML::FormObject::NodetypeMenu;
use vars qw( $DB );

package main;

use vars qw( $AUTOLOAD );
use Test::More tests => 41;
use Test::MockObject;

my $package = 'Everything::HTML::FormObject::NodetypeMenu';

{
	my @imports;
	my @modules = ( 'Everything', 'Everything::HTML::FormObject::TypeMenu' );

	for (@modules)
	{
		Test::MockObject->fake_module( $_,
			import => sub { push @imports, $_[0] } );
	}

	use_ok($package);

	for ( 0 .. $#modules )
	{
		is( $imports[$_], $modules[$_], "Module should use $modules[$_]" );
	}
}

# genObject()
{
	my $mock = Test::MockObject->new;

	my ( %gpa, @gpa );
	$mock->fake_module( $package,
		getParamArray =>
			sub { push @gpa, \@_; return @gpa{qw( q bn f n ou U no i it )} } );

	my @go;
	$mock->fake_module(
		'Everything::HTML::FormObject::TypeMenu',
		genObject => sub { push @go, \@_; return 'html' }
	);

	@gpa{qw( q bn f n ou U no i )} = (
		'query',    'bindNode', 'field', 'name',
		'omitutil', 'USER',     'none',  'inherit'
	);

	my $result = genObject( $mock, 1, 2, 3 );
	is( @gpa, 1, 'genObject() should call getParamArray' );
	is(
		$gpa[0][0],
		'query, bindNode, field, name, omitutil, '
			. 'USER, none, inherit, inherittxt',
		'... requesting the appropriate arguments'
	);
	is_deeply(
		[ @{ $gpa[0] }[ 1 .. 3 ] ],
		[ 1, 2, 3 ],
		'... with the method arguments'
	);
	unlike( join( ' ', @{ $gpa[0] } ),
		qr/$mock/, '... but not the object itself' );
	is( @go, 1, '... should call SUPER::genObject()' );
	is_deeply(
		[ @{ $go[0] } ],
		[
			$mock,  'query',    'bindNode', 'field',
			'name', 'nodetype', 'AUTO',     'USER',
			'c',    'none',     'inherit'
		],
		'... passing ten correct args'
	);
	is( $mock->{omitutil}, 'omitutil',
		'... should set $$this{omitutil} to $omitutil' );

	@gpa{qw(ou U)} = ( undef, undef );

	genObject($mock);
	is( $mock->{omitutil}, 0, '... should default $omitutil to 0' );
	is( ${ $go[1] }[7], -1, '... should default $USER to -1' );

	is( $result, 'html', '... should return result of SUPER::genObject()' );
}

# addTypes()
{
	my ( %types, @hTA );
	for ( 'a', 'b', 'c' )
	{
		$types{$_} = Test::MockObject->new;
		$types{$_}->mock( 'hasTypeAccess', sub { push @hTA, $_[0]; 1 } );
		$types{$_}->set_true('derivesFrom');
		$types{$_}->{title} = $_;
	}

	my $db = Test::MockObject->new;
	$db->set_list( 'getAllTypes', $types{c}, $types{a}, $types{b} );
	$Everything::HTML::FormObject::NodetypeMenu::DB = $db;

	my $mock = Test::MockObject->new;
	$mock->set_always( 'createTree',
		[ { label => 'l1', value => 'v1' }, { label => 'l2', value => 'v2' } ]
	);
	$mock->set_true('addHash');
	$mock->set_true('addArray');
	$mock->set_true('addLabels');

	my $result = addTypes( $mock, 't', 'U', 'p', 'n', 'i' );

	my ( $method, $args ) = $mock->next_call;
	is( $method, 'addHash',
		'addTypes() should call addHash() if $none defined' );
	is_deeply(
		[ @$args[ 1, 2 ] ],
		[ { 'None' => 'n' }, 1 ],
		'... passing {"None" => $none}, 1'
	);

	( $method, $args ) = $mock->next_call;
	is( $method, 'addHash', '... should call addHash() if $inherit defined' );
	is_deeply(
		[ @$args[ 1, 2 ] ],
		[ { 'Inherit' => 'i' }, 1 ],
		'... passing {"Inherit" => $inherit}, 1'
	);

	( $method, $args ) = $db->next_call;
	is( $method, 'getAllTypes', '... should call $DB->getAllTypes' );

	is_deeply(
		[@hTA],
		[ @types{qw(a b c)} ],
		'... should sort returned types by title'
	);

	my $type = Test::MockObject->new;
	$type->set_series( 'hasTypeAccess', 1, 1, 1, 0 );
	$type->set_series( 'derivesFrom',   0, 1, 1, 0 );
	$type->{title} = 'title';
	$db->set_always( 'getAllTypes', $type );

	$mock->{omitutil} = 1;
	$mock->clear;

	addTypes( $mock, 't', 'U', 'p', undef, undef );

	( $method, $args ) = $type->next_call;
	is( $method, 'hasTypeAccess', '... should check hasTypeAccess() for type' );
	is_deeply( [ @$args[ 1 .. 2 ] ], [ 'U', 'c' ],
		'... passing $USER and "c"' );

	( $method, $args ) = $type->next_call;
	is( $method, 'derivesFrom',
		'... should check derivesFrom() if $this->{omitutil}' );
	is( $args->[1], 'utility', '... passing "utility"' );

	( $method, $args ) = $mock->next_call;
	isnt( $method, 'addHash',
		'... should not call addHash() when no $none or $inherit' );
	is( $method, 'createTree', '... should call createTree()' );
	is_deeply( $$args[1], [$type],
		'... passing it $TYPE if hasTypeAccess() and not derivesFrom()' );

	$mock->clear;

	addTypes( $mock, 't', 'U', 'p', undef, undef );
	( $method, $args ) = $mock->next_call;
	is_deeply( [ @{ $$args[1] } ],
		[], '... not passing it $TYPE if derivesFrom() and $omitutil' );

	$mock->{omitutil} = 0;
	$mock->clear;

	addTypes( $mock, 't', 'U', 'p', undef, undef );

	( $method, $args ) = $mock->next_call;
	is_deeply( $$args[1], [$type],
		'... passing it $TYPE if hasTypeAccess() and not $omitutil' );

	$mock->clear;

	addTypes( $mock, 't', 'U', 'p', undef, undef );

	( $method, $args ) = $mock->next_call;
	is_deeply( [ @{ $$args[1] } ],
		[], '... not passing it $TYPE if not hasTypeAccess()' );

	( $method, $args ) = $mock->next_call;
	is( $method, 'addArray', '... should call addArray()' );
	is_deeply(
		$$args[1],
		[ 'v1', 'v2' ],
		'... passing it ref to array of menu values'
	);

	( $method, $args ) = $mock->next_call;
	is( $method, 'addLabels', '... should call addLabels()' );
	is_deeply(
		$$args[1],
		{ l2 => 'v2', l1 => 'v1' },
		'... passing it ref to hash of all menu label/value pairs'
	);
	is( $$args[2], 1, '... and passing it 1' );

	is( $result, 1, '... should return 1' );
}

# createTree()
{
	my $mock = Test::MockObject->new;
	$mock->set_always( 'createTree', [ { label => 'v1' }, { label => 'v2' } ] );

	my $types = [
		{ extends_nodetype => 0, title => 'zero', node_id => 1 },
		{ extends_nodetype => 1, title => 'one1', node_id => 2 },
		{ extends_nodetype => 1, title => 'one2', node_id => 3 },
	];

	createTree( $mock, $types, 1 );

	my ( $method, $args ) = $mock->next_call;
	is( $method, 'createTree', 'createTree() should call createTree()' );
	is_deeply( $args, [ $mock, $types, 2 ], '... passing it $types, node_id' );

	( $method, $args ) = $mock->next_call;
	is_deeply(
		[ $method, @$args ],
		[ 'createTree', $mock, $types, 3 ],
		'... for each $type with extends_nodetype matching $current'
	);

	( $method, $args ) = $mock->next_call;
	ok( !$method, '... but no more' );

	$mock->set_always( 'createTree', [ { label => 'v1' }, { label => 'v2' } ] );
	my $result = createTree( $mock, $types, undef );

	( $method, $args ) = $mock->next_call;
	is( $$args[2], 1, '... $current defaults to 0' );

	is_deeply(
		$result,
		[
			{ label => ' + zero', value => 1 },
			{ label => ' - -v1' },
			{ label => ' - -v2' }
		],
		'... should return correct nodetype tree'
	);
}

sub AUTOLOAD
{
	my ($subname) = $AUTOLOAD =~ /([^:]+)$/;

	if ( my $sub = $package->can( $subname ) )
	{
		$sub->(@_);
	}
	else
	{
		warn "Cannot call <$subname> in ($package)\n";
	}
}
