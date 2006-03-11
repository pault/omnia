#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN
{
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 13;

$INC{'Everything.pm'} = $INC{'Everything/HTML/FormObject.pm'} = 1;

{
	local (
		*Everything::import,
		*Everything::HTML::FormObject::import,
		*Everything::HTML::FormObject::HiddenField::import
	);

	my @imports;
	*Everything::import = *Everything::HTML::FormObject::import = sub {
		push @imports, $_[0];
	};

	*Everything::HTML::FormObject::HiddenField::import = sub { };

	use_ok('Everything::HTML::FormObject::HiddenField');
	is( scalar @imports, 2, 'HiddenField should load two packages' );
	is( $imports[0], 'Everything', '... Everything' );
	is( $imports[1], 'Everything::HTML::FormObject', '... and FormObject' );
}

# genObject()
{
	local (
		*Everything::HTML::FormObject::HiddenField::getParamArray,
		*Everything::HTML::FormObject::HiddenField::SUPER::genObject
	);

	my @params;
	*Everything::HTML::FormObject::HiddenField::getParamArray = sub {
		push @params, "@_";
		shift;
		@_;
	};

	*Everything::HTML::FormObject::HiddenField::SUPER::genObject = sub {
		my $node = shift;
		$node->genObject(@_);
		return 'html';
	};

	my $node = FakeNode->new();    # Fake HiddenField and CGI object
	$node->{_subs}{hidden} = [ 'a', 'b', 'c', 'd' ];
	my $result = genObject( $node, $node, 'bN', 'f', 'n', 'd' );

	is(
		$params[0],
		"query, bindNode, field, name, default $node bN f n d",
		'genObject() should call getParamArray() with @_'
	);
	is( $node->{_calls}[0][0],
		'genObject', '... should call SUPER::genObject()' );
	is( $node->{_calls}[1][0], 'hidden', '... should call hidden()' );
	is( $node->{_calls}[1][4],
		'd', '... should use default value, if provided' );
	is( $node->{_calls}[1][2], 'n', '... should use provided name' );
	is( $result, "html\na",
		'... returning concatenation of SUPER() and hidden() calls' );

	genObject( $node, $node, { f => 'field' }, 'f', 'n', '' );
	is( $node->{_calls}[-1][4],
		'field',
		'... with no default value, should bind to node field (if provided)' );

	genObject( $node, $node, { field => 88 }, 'field', '', 'd' );
	is( $node->{_calls}[-1][2],
		'field', '... name should default to node field name' );

	genObject( $node, $node, '', 'f', 'n', '' );
	is( $node->{_calls}[-1][4],
		'',
		'... default value should be blank if "AUTO" and lacking bound node' );
}

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::HTML::FormObject::HiddenField::$AUTOLOAD";

	if ( defined &{$sub} )
	{
		*{$AUTOLOAD} = \&{$sub};
		goto &{$sub};
	}
}
