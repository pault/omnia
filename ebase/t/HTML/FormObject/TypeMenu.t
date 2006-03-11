#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 32;

$INC{'Everything.pm'} = $INC{'Everything/HTML/FormObject/FormMenu.pm'} = 1;

{
	local (
		*Everything::import,
		*Everything::HTML::FormObject::FormMenu::import,
		*Everything::HTML::FormObject::TypeMenu::import
	);

	my @imports;
	*Everything::import = *Everything::HTML::FormObject::FormMenu::import =
		sub {
		push @imports, $_[0];
		};

	*Everything::HTML::FormObject::TypeMenu::import = sub { };

	use_ok('Everything::HTML::FormObject::TypeMenu');
	is( scalar @imports, 2, 'TypeMenu should load two packages' );
	is( $imports[0], 'Everything', '... Everything' );
	is(
		$imports[1],
		'Everything::HTML::FormObject::FormMenu',
		'... and FormMenu'
	);
}

# genObject()
{
	local (
		*Everything::HTML::FormObject::TypeMenu::getParamArray,
		*Everything::HTML::FormObject::TypeMenu::SUPER::genObject
	);

	my @params;
	*Everything::HTML::FormObject::TypeMenu::getParamArray = sub {
		push @params, "@_";
		shift;
		@_;
	};

	*Everything::HTML::FormObject::TypeMenu::SUPER::genObject = sub {
		my $node = shift;
		$node->genObject(@_);
		return 'html';
	};

	my $node = FakeNode->new();
	$node->{_subs}{genPopupMenu} = [ 'a', 'b', 'c', 'd' ];

	my $result =
		genObject( $node, 'q', 'bN', 'f', 'n', 't', 'd', 'U', 'p', 'n', 'i',
		'it' );

	is(
		$params[0],
		'query, bindNode, field, name, type, default, USER, perm, '
			. 'none, inherit, inherittxt q bN f n t d U p n i it',
		'genObject() should call getParamArray() with @_'
	);
	is( $node->{_calls}[0][0],
		'genObject', '... should call SUPER::genObject()' );
	is( $node->{_calls}[1][0], 'addTypes', '... should call addTypes()' );
	is( $node->{_calls}[2][0],
		'genPopupMenu', '... should call genPopupMenu()' );
	is( $node->{_calls}[2][2], 'n',   '... should use provided $name' );
	is( $node->{_calls}[1][1], 't',   '... should use provided $type' );
	is( $node->{_calls}[1][2], 'U',   '... should use provided $USER' );
	is( $node->{_calls}[1][3], 'p',   '... should use provided $perm' );
	is( $node->{_calls}[2][3], undef, '... $default becomes undef if true' );
	is( $result, "html\na",
		'... returning concatenation of SUPER() and genPopupMenu() calls' );

	genObject( $node, 'q', { f => 'field' }, 'f' );

	is( $node->{_calls}[-2][1],
		'nodetype', '... $type should default to "nodetype"' );
	is( $node->{_calls}[-2][2], '-1', '... $USER should default to -1' );
	is( $node->{_calls}[-2][3], 'r',  '... $perm should default to "r"' );
	is( $node->{_calls}[-1][2], 'f',  '... $name should default to $field' );
	is( $node->{_calls}[-1][3],
		'field',
		'... with no default value, should bind to provided node field' );

	genObject( $node, 'q', '', 'field', '', '', 'AUTO' );
	is( $node->{_calls}[-1][3],
		undef,
		'... default value should be undef if "AUTO" and lacking bound node' );
}

# addTypes()
{
	my $node = FakeNode->new();
	$node->{_subs} = {
		addHash => [ ('H') x 9 ],
		addType => [ ('T') x 9 ]
	};

	my $result = addTypes( $node, 't', 'U', 'p', 'n', 'i', 'it' );
	is( $node->{_calls}[0][0],
		'addHash', 'addTypes() should call addHash() if defined $none' );
	is( $node->{_calls}[1][0],
		'addHash', '... should call addHash() again if defined $inherit' );
	is( $node->{_calls}[2][0], 'addType', '... should call addType()' );
	is( $node->{_calls}[2][2], 'U',       '... should use provided $USER' );
	is( $node->{_calls}[2][3], 'p',       '... and $perm' );
	is( ${ $node->{_calls}[1][1] }{'inherit (it)'},
		'i',
		'... $label should be set to "inherit ($inherittxt)" if $inherittxt' );
	is( $result, 1, '... should return 1' );

	addTypes( $node, 't', '', '', 'n' );
	is( $node->{_calls}[-1][2], -1,  '... $USER defaults to -1' );
	is( $node->{_calls}[-1][3], 'r', '... and $perm to "r"' );
	is( ${ $node->{_calls}[-2][1] }{None},
		'n', '... skip an addHash() if $inherit undefined' );

	addTypes( $node, 't', 'U', 'p', undef, 'i' );
	is( $node->{_calls}[-3][0],
		'addType', '... skip and addHash() if $none undefined' );
	is( ${ $node->{_calls}[-2][1] }{inherit},
		'i', '... $label should be set to "inherit" if no $inherittxt' );
}

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::HTML::FormObject::TypeMenu::$AUTOLOAD";

	if ( defined &{$sub} )
	{
		*{$AUTOLOAD} = \&{$sub};
		goto &{$sub};
	}
}
