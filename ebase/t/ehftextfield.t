#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 17;

$INC{ 'Everything.pm' } = $INC{ 'Everything/HTML/FormObject.pm' } = 1;

{
	local (*Everything::import,*Everything::HTML::FormObject::import,
		*Everything::HTML::FormObject::TextField::import);

	my @imports;
	*Everything::import = *Everything::HTML::FormObject::import = sub{
		push @imports, $_[0];
	};

	*Everything::HTML::FormObject::TextField::import = sub {};

	use_ok( 'Everything::HTML::FormObject::TextField' );
	is( scalar @imports, 2, 'TextField should load two packages' );
	is( $imports[0], 'Everything', '... Everything' );
	is( $imports[1], 'Everything::HTML::FormObject', 
		'... and FormObject' );
}

# genObject()
{
	local (*Everything::HTML::FormObject::TextField::getParamArray,
		*Everything::HTML::FormObject::TextField::SUPER::genObject);

	my @params;
	*Everything::HTML::FormObject::TextField::getParamArray = sub {
		push @params, "@_";
		shift;
		@_;
	};

	*Everything::HTML::FormObject::TextField::SUPER::genObject = sub {
		my $node = shift;
		$node->genObject( @_ );
		return 'html';
	};

	my $node = FakeNode->new();  # Fake TextField and CGI object
	$node->{_subs}{textfield} = [ 'a', 'b', 'c', 'd' ];
	my $result = genObject( $node, $node, 'bN', 'f', 'n', 'd', 's', 'm' );

	is( $params[0], 'query, bindNode, field, name, default, size, maxlen ' . 
		$node . ' bN f n d s m',
		'genObject() should call getParamArray() with @_' );
	is( $node->{_calls}[0][0], 'genObject',
		'... should call SUPER::genObject()' );
	is( $node->{_calls}[1][0], 'textfield',
		'... should call textfield()' );
	is( $node->{_calls}[1][4], 'd', 
		'... should use default value, if provided' );
	is( $node->{_calls}[1][2], 'n', 
		'... should use provided name' );
	is( $node->{_calls}[1][6], 's',
		'... should use provided size' );
	is( $node->{_calls}[1][8], 'm',
		'... should use provided maxlen' );
	is( $result, "html\na", 	
		'... returning concatenation of SUPER() and textfield() calls' );

	genObject( $node, $node, { f => 'field' }, 'f', '', '' );
	is( $node->{_calls}[-1][4], 'field', 
		'... with no default value, should bind to node field (if provided)' );
	is( $node->{_calls}[-1][6], 20,
		'... size should default to 20' );
	is( $node->{_calls}[-1][8], 255,
		'... maxlen should default to 255' );
	is( $node->{_calls}[-1][2], 'f', 
		'... name should default to node field name' );

	genObject( $node, $node, '', 'f', 'n', '' );
	is( $node->{_calls}[-1][4], '',
		'... default value should be blank if "AUTO" and lacking bound node' );
}

sub AUTOLOAD {
    return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::HTML::FormObject::TextField::$AUTOLOAD";

	if (defined &{ $sub }) {
		*{ $AUTOLOAD } = \&{ $sub };
		goto &{ $sub };
	}
}
