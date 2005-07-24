#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 23;

$INC{ 'Everything.pm' } = $INC{ 'Everything/HTML/FormObject/Checkbox.pm' } = 1;

{
	local (*Everything::import, *Everything::HTML::FormObject::Checkbox::import,
		*Everything::HTML::FormObject::RemoveVarCheckbox::import);

	my @imports;
	*Everything::import = *Everything::HTML::FormObject::Checkbox::import = sub{
		push @imports, $_[0];
	};

	*Everything::HTML::FormObject::RemoveVarCheckbox::import = sub {};

	use_ok( 'Everything::HTML::FormObject::RemoveVarCheckbox' );

	is( scalar @imports, 2, 'RemoveVarCheckbox should load two packages' );
	is( $imports[0], 'Everything', '... Everything' );
	is( $imports[1], 'Everything::HTML::FormObject::Checkbox', 
		'... and Checkbox' );
}

my $node = FakeNode->new();

# genObject()
{
	local (*Everything::HTML::FormObject::RemoveVarCheckbox::getParamArray,
		*Everything::HTML::FormObject::RemoveVarCheckbox::SUPER::genObject);

	my @params;
	*Everything::HTML::FormObject::RemoveVarCheckbox::getParamArray = sub {
		push @params, "@_";
		shift;
		@_;
	};

	*Everything::HTML::FormObject::RemoveVarCheckbox::SUPER::genObject = sub {
		my $node = shift;
		$node->genObject( @_ );
		return 'html';
	};

	genObject( $node, $node, 'bN', 'f', 'v' );
	is( $params[0], "query, bindNode, field, var $node bN f v",
		'genObject() should call getParamArray() with @_' );
	
	is( $node->{updateExecuteOrder}, 55, 
		'... should set node execution order to 55' );
	
	my $call = $node->{_calls}[0];
	is( $call->[0], 'genObject',
		'... should call SUPER::genObject()' );

	is( $call->[2], 'bN', '... passing bound node' );
	is( $call->[3], 'f:v', '... field and variable name' );
	is( $call->[4], 'remove_f_v', '... name' );
	is( join(' ', @$call[5, 6]), 'remove UNCHECKED',
		'... and "remove" and "UNCHECKED" args' );
	
	is( genObject($node, 1 .. 4), "html\n", 
		'... should return result of SUPER call' );
}

# cgiUpdate()
$node->{_subs} = {
	param => [ 0, (1) x 3 ],
	getBindField => [ ('field::var') x 3 ],
	getHash => [ ($node) x 3 ],
	verifyFieldUpdate => [ 0, 1 ],
};

my $result = cgiUpdate( $node, $node, 'name' );
is( join(' ', @{ $node->{_calls}[-1] }), 'param name',
	'cgiUpdate() should call fetch named param' );
ok( ! $result, '... and should return false if none exists' );

$node->{_calls} = [];
$node->{var} = 'foo';

$result = cgiUpdate( ($node) x 4, 1 );
is( $node->{_calls}[1][0], 'getBindField',
	'... should call getBindField() to find field' );
isnt( $node->{_calls}[2][0], 'verifyFieldUpdate', 
	'... should bypass field verification check if $overrideVerify is true'  );
is( join(' ', @{ $node->{_calls}[2] }), 'getHash field',
	'... should call getHash() on field' );
ok( ! exists $node->{var}, '... and should delete variable in bound node' );
is( join(' ', @{ $node->{_calls}[3] }), "setHash $node field",
	'... should call setHash() to update node' );
ok( $result, '... and should return true' );

$result = cgiUpdate( ($node) x 4, 0 );
ok( ! $result, '... should return false if field update cannot be verified' );
is( join(' ', @{ $node->{_calls}[-1] }), 'verifyFieldUpdate field',
	'... (so should call verifyFieldUpdate() on node field)' );
ok( cgiUpdate( ($node) x 4, 1 ), '... should continue if update verifies' );

sub AUTOLOAD {
    return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::HTML::FormObject::RemoveVarCheckbox::$AUTOLOAD";

	if (defined &{ $sub }) {
		*{ $AUTOLOAD } = \&{ $sub };
		goto &{ $sub };
	}
}
