#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 13;

$INC{ 'Everything.pm' } = $INC{ 'Everything/HTML/FormObject/FormMenu.pm' } = 1;

{
	local (*Everything::import,*Everything::HTML::FormObject::FormMenu::import,
		*Everything::HTML::FormObject::PopupMenu::import);

	my @imports;
	*Everything::import = *Everything::HTML::FormObject::FormMenu::import = sub{
		push @imports, $_[0];
	};

	*Everything::HTML::FormObject::PopupMenu::import = sub {};

	use_ok( 'Everything::HTML::FormObject::PopupMenu' );
	is( scalar @imports, 2, 'PopupMenu should load two packages' );
	is( $imports[0], 'Everything', '... Everything' );
	is( $imports[1], 'Everything::HTML::FormObject::FormMenu', 
		'... and FormMenu' );
}

# genObject()
{
	local (*Everything::HTML::FormObject::PopupMenu::getParamArray,
		*Everything::HTML::FormObject::PopupMenu::SUPER::genObject);

	my @params;
	*Everything::HTML::FormObject::PopupMenu::getParamArray = sub {
		push @params, "@_";
		shift;
		@_;
	};

	*Everything::HTML::FormObject::PopupMenu::SUPER::genObject = sub {
		my $node = shift;
		$node->genObject( @_ );
		return 'html';
	};

	my $node = FakeNode->new();
	$node->{_subs}{genPopupMenu} = [ 'a', 'b', 'c', 'd' ];
	my $result = genObject( $node, 'q', 'bN', 'f', 'n', 'd' );

	is( $params[0], 'query, bindNode, field, name, default q bN f n d',
		'genObject() should call getParamArray() with @_' );
	
	is( $node->{_calls}[0][0], 'genObject',
		'... should call SUPER::genObject()' );
	is( $node->{_calls}[1][0], 'genPopupMenu',
		'... should call genPopupMenu()' );

	is( $node->{_calls}[1][3], 'd', 
		'... should use default value, if provided' );
	is( $node->{_calls}[1][2], 'n', '... should use provided name' );
	is( $result, "html\na", 	
		'... returning concatenation of SUPER() and genPopupMenu() calls' );

	genObject( $node, 'q', { f => 'field' }, 'f', 'n' );
	is( $node->{_calls}[-1][3], 'field', 
		'... with no default value, should bind to node field (if provided)' );
	
	genObject( $node, 'q', { field => 88 }, 'field' );
	is( $node->{_calls}[-1][2], 'field', 
		'... name should default to node field name' );
	
	genObject( $node, 'q', '', 'field' );
	is( $node->{_calls}[-1][3], '',
		'... default value should be blank if "AUTO" and lacking bound node' );
}

sub AUTOLOAD {
    return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::HTML::FormObject::PopupMenu::$AUTOLOAD";

	if (defined &{ $sub }) {
		*{ $AUTOLOAD } = \&{ $sub };
		goto &{ $sub };
	}
}
