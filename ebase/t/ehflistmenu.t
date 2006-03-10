#!/usr/bin/perl -w

use strict;

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use vars qw( $AUTOLOAD );

use Test::More tests => 32;
use Test::MockObject;
my $mock    = Test::MockObject->new();
my $package = 'Everything::HTML::FormObject::ListMenu';

{
	my @imports;
	my @modules = ( 'Everything', 'Everything::HTML::FormObject::FormMenu' );

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
	my ( %gpa, @gpa );
	$mock->fake_module( $package,
		getParamArray =>
			sub { push @gpa, \@_; return @gpa{qw( q bn f n d m v s l sb )} } );

	my @go;
	$mock->fake_module(
		'Everything::HTML::FormObject::FormMenu',
		genObject => sub { push @go, \@_; return 'html1' }
	);

	for ( 'clearMenu', 'addArray', 'addLabels', 'sortMenu' )
	{
		$mock->set_true($_);
	}
	$mock->set_always( 'genListMenu', 'html2' );

	@gpa{qw( q bn f n d m v s l sb )} = (
		$mock, '',     'field', 'name', 'def', 'mul',
		'val', 'size', 'lab',   'sort'
	);

	my $result = genObject( $mock, 1, 2, 3 );
	is( @gpa, 1, 'genObject() should call getParamArray' );
	is(
		$gpa[0][0],
		'query, bindNode, field, name, default, '
			. 'multiple, values, size, labels, sortby',
		'... requesting the appropriate arguments'
	);
	like( join( ' ', @{ $gpa[0] } ),
		qr/1 2 3$/, '... with the method arguments' );
	unlike( join( ' ', @{ $gpa[0] } ),
		qr/$mock/, '... but not the object itself' );

	my ( $method, $args ) = $mock->next_call();
	is( 'clearMenu', $method, '... should call clearMenu' );
	is( join( ' ', @$args ), "$mock", '... passing one arg ($this)' );

	( $method, $args ) = $mock->next_call();
	is( 'addArray', $method, '... should call addArray' );
	is( join( ' ', @$args ),
		"$mock val", '... passing two args ($this, $values)' );

	( $method, $args ) = $mock->next_call();
	is( 'addLabels', $method, '... should call addLabels' );
	is( join( ' ', @$args ),
		"$mock lab", '... passing two args ($this, $labels)' );

	( $method, $args ) = $mock->next_call();
	is( 'sortMenu', $method, '... should call sortMenu' );
	is( join( ' ', @$args ),
		"$mock sort", '... passing two args ($this, $sortby)' );

	( $method, $args ) = $mock->next_call();
	is( 'genListMenu', $method, '... should call genListMenu' );
	is( "@$args", "@gpa{qw( q q n d s m )}", '... passing the correct args' );
	is( $$args[3], 'def',
		'... $default should remain unchanged when not AUTO' );

	$gpa{d} = 'AUTO';
	genObject($mock);
	( $method, $args ) = $mock->next_call(5);
	is( $$args[3], '', '... should be blank if AUTO and no $bindNode' );

	$gpa{bn} = { field => "1,2" };
	genObject($mock);
	( $method, $args ) = $mock->next_call(5);
	is( "@{$$args[3]}", "1 2",
		'... and should be $$bindNode{$field} if AUTO and $bindNode' );

	is( $result, "html1\nhtml2",
		'... should return parent object plus genListMenu html' );
}

# cgiUpdate()
{
	my $qmock = Test::MockObject->new();
	$qmock->set_true('param');

	my $nmock = Test::MockObject->new();
	$nmock->set_series( 'verifyFieldUpdate', 0, 1, 0 );

	$mock->set_always( 'getBindField', 'field' );

	my @results;
	push @results, cgiUpdate( $mock, $qmock, 'name', $nmock, 0 );
	my ( $method, $args ) = $mock->next_call();
	is( $method, 'getBindField', 'cgiUpdate() should call getBindField' );
	is( "@$args", "$mock $qmock name", '... passing two args ($query, $name)' );

	( $method, $args ) = $nmock->next_call();
	is( $method, 'verifyFieldUpdate',
		'... should check verifyFieldUpdate if not $overrideVerify' );
	is( "@$args", "$nmock field", '... passing it one arg ($field)' );
	ok( !$qmock->called('param'),
		'... should not call param() when verify off' );

	push @results, cgiUpdate( $mock, $qmock, 'name', $nmock, 0 );
	( $method, $args ) = $qmock->next_call();
	is( $method, 'param',
		'... should call param() if $NODE->verifyFieldUpdate' );
	is( "@$args", "$qmock name", '... passing one arg ($name)' );

	push @results, cgiUpdate( $mock, $qmock, 'name', $nmock, 1 );
	ok( $qmock->called('param'), '... should call param() if $overrideVerify' );

	ok( !$results[0], '... should return false when verify is off' );
	ok( $results[1],  '... should return true if $NODE->verifyFieldUpdate' );
	ok( $results[2],  '... should return true if $overrideVerify' );
}

sub AUTOLOAD
{
	my ($subname) = $AUTOLOAD =~ /([^:]+)$/;

	if ( my $sub = UNIVERSAL::can( $package, $subname ) )
	{
		$sub->(@_);
	}
	else
	{
		warn "Cannot call <$subname> in ($package)\n";
	}
}

