#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 14;

$INC{ 'Everything.pm' } = $INC{ 'Everything/HTML/FormObject/FormMenu.pm' } = 1;

{
	local (*Everything::import,*Everything::HTML::FormObject::FormMenu::import,
		*Everything::HTML::FormObject::RadioGroup::import);

	my @imports;
	*Everything::import = *Everything::HTML::FormObject::FormMenu::import = sub{
		push @imports, $_[0];
	};

	*Everything::HTML::FormObject::RadioGroup::import = sub {};

	use_ok( 'Everything::HTML::FormObject::RadioGroup' );
	is( scalar @imports, 2, 'RadioGroup should load two packages' );
	is( $imports[0], 'Everything', '... Everything' );
	is( $imports[1], 'Everything::HTML::FormObject::FormMenu', 
		'... and FormMenu' );
}

my $node = FakeNode->new();

# genObject()
{
	local (*Everything::HTML::FormObject::RadioGroup::getParamArray,
		*Everything::HTML::FormObject::RadioGroup::SUPER::genObject,
		*FakeNode::radio_group);

	my @params;
	*Everything::HTML::FormObject::RadioGroup::getParamArray = sub {
		push @params, "@_";
		shift;
		@_;
	};

	*Everything::HTML::FormObject::RadioGroup::SUPER::genObject = sub {
		my $node = shift;
		$node->genObject( @_ );
		return 'html';
	};

	*FakeNode::radio_group = sub {
		my $node = shift;
		push @{ $node->{_calls} }, [ 'radio_group', @_ ];
		return ('a', 'b');
	};

	genObject( $node, $node, 'bN', 'f', 'n', 'd', 'v' );
	is( $params[0], "query, bindNode, field, name, default, vertical $node " . 
		'bN f n d v', 'genObject() should call getParamArray() with @_' );
	is( $node->{_calls}[0][0], 'genObject',
		'... should call SUPER::genObject()' );
	is( $node->{_calls}[1][0], 'getValuesArray',
		'... should call getValuesArray()' );
	is( $node->{_calls}[2][0], 'getLabelsHash',
		'... should call getLabelsHash()' );
	is( $node->{_calls}[3][0], 'radio_group',
		'... should call $query->radio_group()' );

	genObject( $node, $node, { f => 'field' }, 'f', 'n', 'AUTO' );
	is( $node->{_calls}[-1][4], 'field', 
		'... default value should bind to node field if "AUTO"' );
	
	genObject( $node, $node, '', 'field', 'n', 'AUTO' );
	is( $node->{_calls}[-1][4], '',
		'... default value should be blank if "AUTO" and lacking bound node' );

	is( genObject( $node, $node, 'bN', 'f', 'n', 'd', 0 ), "html\na\nb",
		'... join buttons using "\n" if vertical is false' );
	ok( is( genObject( $node, $node, 'bN', 'f', 'n', 'd', 1 ), "html\na<br>\nb",
			'... and join using "<br>\n" if vertical is true' ),
		'... returns concatenation of SUPER() and radio_group() calls' ); 
}

sub AUTOLOAD {
    return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::HTML::FormObject::RadioGroup::$AUTOLOAD";

	if (defined &{ $sub }) {
		*{ $AUTOLOAD } = \&{ $sub };
		goto &{ $sub };
	}
}
