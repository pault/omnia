#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 19;

$INC{ 'Everything.pm' } = $INC{ 'Everything/HTML/FormObject.pm' } = 1;

{
	local (*Everything::import,*Everything::HTML::FormObject::import,
		*Everything::HTML::FormObject::TextArea::import);

	my @imports;
	*Everything::import = *Everything::HTML::FormObject::import = sub{
		push @imports, $_[0];
	};

	*Everything::HTML::FormObject::TextArea::import = sub {};

	use_ok( 'Everything::HTML::FormObject::TextArea' );
	is( scalar @imports, 2, 'TextArea should load two packages' );
	is( $imports[0], 'Everything', '... Everything' );
	is( $imports[1], 'Everything::HTML::FormObject', 
		'... and FormObject' );
}

# genObject()
{
	local (*Everything::HTML::FormObject::TextArea::getParamArray,
		*Everything::HTML::FormObject::TextArea::SUPER::genObject);

	my @params;
	*Everything::HTML::FormObject::TextArea::getParamArray = sub {
		push @params, "@_";
		shift;
		@_;
	};

	*Everything::HTML::FormObject::TextArea::SUPER::genObject = sub {
		my $node = shift;
		$node->genObject( @_ );
		return 'html';
	};

	my $node = FakeNode->new();  # Fake TextArea and CGI object
	$node->{_subs}{textarea} = [ 'a', 'b', 'c', 'd' ];
	my $result = genObject( $node, $node, 'bN', 'f', 'n', 'd', 'c', 'r', 'w' );

	is( $params[0], 'query, bindNode, field, name, default, cols, rows, wrap ' .
		$node . ' bN f n d c r w',
		'genObject() should call getParamArray() with @_' );
	is( $node->{_calls}[0][0], 'genObject',
		'... should call SUPER::genObject()' );
	is( $node->{_calls}[1][0], 'textarea',
		'... should call textarea()' );
	is( $node->{_calls}[1][4], 'd', 
		'... should use default value, if provided' );
	is( $node->{_calls}[1][2], 'n', 
		'... should use provided name' );
	is( $node->{_calls}[1][6], 'c',
		'... should use provided cols' );
	is( $node->{_calls}[1][8], 'r',
		'... should use provided rows' );
	is( $node->{_calls}[1][10], 'w',
		'... should use provided wrap' );
	is( $result, "html\na", 	
		'... returning concatenation of SUPER() and textfield() calls' );

	genObject( $node, $node, { f => 'field' }, 'f' );
	is( $node->{_calls}[-1][4], 'field', 
		'... with no default value, should bind to node field (if provided)' );
	is( $node->{_calls}[-1][6], 80,
		'... cols should default to 80' );
	is( $node->{_calls}[-1][8], 20,
		'... rows should default to 20' );
	is( $node->{_calls}[-1][10], 'virtual',
		'... wrap should default to "virtual"' );
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

	my $sub = "Everything::HTML::FormObject::TextArea::$AUTOLOAD";

	if (defined &{ $sub }) {
		*{ $AUTOLOAD } = \&{ $sub };
		goto &{ $sub };
	}
}
