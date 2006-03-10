#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 28;

$INC{'Everything.pm'} = $INC{'Everything/HTML/FormObject.pm'} = 1;

{
	local (
		*Everything::import,
		*Everything::HTML::FormObject::import,
		*Everything::HTML::FormObject::Checkbox::import
	);

	my @imports;
	*Everything::import = *Everything::HTML::FormObject::import = sub {
		push @imports, $_[0];
	};

	*Everything::HTML::FormObject::Checkbox::import = sub { };

	use_ok('Everything::HTML::FormObject::Checkbox');

	is( scalar @imports, 2, 'Checkbox should load two packages' );
	is( $imports[0], 'Everything', '... Everything' );
	is( $imports[1], 'Everything::HTML::FormObject', '... and FormObject' );
}

my $node = FakeNode->new();

# genObject()
{
	local (
		*Everything::HTML::FormObject::Checkbox::getParamArray,
		*Everything::HTML::FormObject::Checkbox::SUPER::genObject
	);

	my @params;
	*Everything::HTML::FormObject::Checkbox::getParamArray = sub {
		push @params, "@_";
		shift;
		@_;
	};

	*Everything::HTML::FormObject::Checkbox::SUPER::genObject = sub {
		my $node = shift;
		$node->genObject(@_);
		return 'html';
	};

	$node->{_subs}{checkbox} = [ 'a', 'b', 'c', 'd', 'e' ];

	my $result = genObject( $node, $node, 'bN', 'f', 'n', 'c', 'u', 'd', 'l' );
	is(
		$params[0],
		'query, bindNode, field, name, checked, unchecked, default, label'
			. " $node bN f n c u d l",
		'genObject() should call getParamArray() with @_'
	);
	is( $node->{_calls}[0][0], 'genObject', '... and SUPER::genObject()' );
	is( $node->{_calls}[1][0], 'checkbox',  '... and $q->checkbox()' );
	like( $node->{_calls}[0][3], qr/^.+:u$/, '... uses provided $unchecked' );
	like( $node->{_calls}[0][3], qr/^f:.+$/, '... and $field' );
	is( $node->{_calls}[0][4], 'n', '... and $name' );
	is( $node->{_calls}[1][4], 'd', '... and $default' );
	is( $node->{_calls}[1][6], 'c', '... and $checked' );
	is( $node->{_calls}[1][8], 'l', '... and $label' );
	is( $result, "html\na",
		'... should return concantation of SUPER() and checkbox() calls' );

	genObject( $node, $node, 'bindNode', 'field' );
	is( $node->{_calls}[-2][3],
		'field:0', '... when not provided, $unchecked defaults to 0' );
	is( $node->{_calls}[-1][6], 1, '... and $checked to 1' );
	is( $node->{_calls}[-1][4],
		0, '... with no $bindNode, $default defaults to 0' );

	genObject( $node, $node, { f => '1' }, 'f' );
	is( $node->{_calls}[-1][4], 1,
		'... with $bindNode and $checked eq $$bindNode{$field}, defaults to 1'
	);

	genObject( $node, $node, { f => '0' }, 'f' );
	is( $node->{_calls}[-1][4], 0,
		'... with $bindNode and $checked ne $$bindNode{$field}, defaults to 0'
	);

	genObject( $node, $node, '', '', '', '', '', 'AUTO' );
	is( $node->{_calls}[-1][4], 0,
		'... same when provided $default is "AUTO"' );
}

# cgiUpdate()
$node->{_subs} = {
	param => [ 345, 0, 0 ],
	getBindField => [ ('field:var') x 3 ],
	verifyFieldUpdate => [ 1, 0, 0 ],
};

my @results;

push @results, cgiUpdate( $node, $node, 'name', $node, 0 );
is( join( '', @{ $node->{_calls}[-3] } ),
	'paramname', 'cgiUpdate() should call param() with $name' );
is( join( '', @{ $node->{_calls}[-2] } ),
	"getBindField${node}name",
	'... should call getBindField() with $query, $name' );
is( join( '', @{ $node->{_calls}[-1] } ),
	'verifyFieldUpdatefield',
	'... should call verifyFieldUpdate() with $field' );
is( $node->{field}, 345, '... should set $NODE->{$field} to $value if true' );

push @results, cgiUpdate( $node, $node, 'name', $node, 1 );
is( $node->{field}, 'var', '... and to $unchecked if not' );

push @results, cgiUpdate( $node, $node, 'name', $node, 0 );
is( $results[2], 0, '... should return 0' );
is( $results[1], 1, '... unless $overrideVerify is true' );
is( $results[0], 1, '... or $NODE->verifyFieldUpdate($field) is true' );

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::HTML::FormObject::Checkbox::$AUTOLOAD";

	if ( defined &{$sub} )
	{
		*{$AUTOLOAD} = \&{$sub};
		goto &{$sub};
	}
}
