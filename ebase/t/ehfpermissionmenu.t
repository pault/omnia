#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib/', '..';
}

use FakeNode;
use Test::More tests => 26;

$INC{ 'Everything.pm' } = $INC{ 'Everything/HTML/FormObject/FormMenu.pm' } = 1;

{
	local (*Everything::import,*Everything::HTML::FormObject::FormMenu::import,
		*Everything::HTML::FormObject::PermissionMenu::import);

	my @imports;
	*Everything::import = *Everything::HTML::FormObject::FormMenu::import = sub{
		push @imports, $_[0];
	};

	*Everything::HTML::FormObject::PermissionMenu::import = sub {};

	use_ok( 'Everything::HTML::FormObject::PermissionMenu' );
	is( scalar @imports, 2, 'TypeMenu should load two packages' );
	is( $imports[0], 'Everything', '... Everything' );
	is( $imports[1], 'Everything::HTML::FormObject::FormMenu', 
		'... and FormMenu' );
}

# genObject()
{
	local (*Everything::HTML::FormObject::PermissionMenu::getParamArray,
		*Everything::HTML::FormObject::PermissionMenu::SUPER::genObject);

	my @params;
	*Everything::HTML::FormObject::PermissionMenu::getParamArray = sub {
		push @params, "@_";
		shift;
		@_;
	};

	*Everything::HTML::FormObject::PermissionMenu::SUPER::genObject = sub {
		my $node = shift;
		$node->genObject( @_ );
		return 'html';
	};

	my $node = FakeNode->new();
	$node->{_subs}{genPopupMenu} = [ 'a', 'b', 'c', 'd' ];
	
	my $result = genObject( $node, 'q', 'bN', 'f', 'n', 'r', 'd' );
	is( $params[0], 'query, bindNode, field, name, perm, default q bN f n r d',
		'genObject() should call getParamArray() with @_' );
	is( $node->{_calls}[0][0], 'genObject',
		'... should call SUPER::genObject()' );
	is( $node->{_calls}[1][0], 'addHash',
		'... should call addHash()' );
	is( $node->{_calls}[2][0], 'addHash',
                '... and addHash()' );
	is( $node->{_calls}[3][0], 'addHash',
                '... and addHash() once again' );
	is( $node->{_calls}[4][0], 'genPopupMenu',
		'... and genPopupMenu()' );
	is( $node->{_calls}[4][2], 'n', 
		'... should use provided $name' );
	is( $node->{_calls}[4][3], undef,
		'... $default becomes undef if true and not "AUTO"' );
	is( $result, "html\na", 	
		'... returning concatenation of SUPER() and genPopupMenu() calls' );

	genObject( $node, 'q', { f => '12345' }, 'f', '', 'x' );
	is( $node->{_calls}[-1][2], 'f',
		'... $name should default to $field' );
	is( $node->{_calls}[-1][3], '3',
		'... if false, set $default to substr($perms, $$bindNode{$field}, 1)' );

	genObject( $node, 'q', '', 'field', '', 'r', 'AUTO' );
	is( $node->{_calls}[-1][3], undef,
		'... default value should be undef if "AUTO" and lacking bound node' );

	my $warning;
	local $SIG{__WARN__} = sub { 
		$warning = shift 
	};

	$result = genObject( $node, '', '', '', '', 'wrong' );
	like( $warning, qr/incorrect permission/i,
		'... should warn on invalid $perm' );
	is( $result, '',
		'... and should return ""' ); 
}

# cgiUpdate()
{
	my $node = FakeNode->new();
	$node->{_subs} = {
		param => [ 'p', '', ''  ],
		getBindField => [ 'f:x', 'f:x', 'f:x' ],
		verifyFieldUpdate => [ 1, 0, 0 ] 
	};
	$node->{f} = 'rrrrr';

	my $result = cgiUpdate( $node, $node, 'n', $node, 0 );
	is( $node->{_calls}[0][0], 'param',
		'cgiUpdate() should call param()' );
	is( $node->{_calls}[1][0], 'getBindField',
		'... and getBindField()' );
	is( $node->{_calls}[2][0], 'verifyFieldUpdate',
		'... and verifyFieldUpdate() if $overrideVerify is false' );
        is( $node->{f}, 'rrprr',
                '... should set correct char in $$NODE{$field} to $value' );
	is( $result, 1,
		'... should return 1 if verifyFieldUpdate() is true' );

	$result = cgiUpdate( $node, $node, 'n', $node, 1 );
	is( $node->{f}, 'rrirr',
		'... $value should default to "i"' );
	is( $result, 1,
		'... should return 1 if $overrideVerify is true' );

	$result = cgiUpdate( $node, $node, 'n', $node, 0 );
	is( $result, 0,
		'... should return 0 if !($overrideVerify or verifyFieldUpdate())' );
}

sub AUTOLOAD {
    return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::HTML::FormObject::PermissionMenu::$AUTOLOAD";

	if (defined &{ $sub }) {
		*{ $AUTOLOAD } = \&{ $sub };
		goto &{ $sub };
	}
}
