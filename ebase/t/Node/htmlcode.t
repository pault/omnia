#!/usr/bin/perl

use strict;
use warnings;

use vars qw( $AUTOLOAD $errors );

BEGIN
{
	chdir 't' if -d 't';
	use lib 'lib';
}

use Test::More tests => 6;

my $module = 'Everything::Node::htmlcode';
use_ok( $module ) or exit;
ok( $module->isa( 'Everything::Node::node' ), 'htmlcode should extend node' );

local *Everything::logErrors;
*Everything::logErrors = sub
{
	$main::errors = join( ' ', @_ );
};

# restrictTitle()
ok( !restrictTitle( {} ), 'restrictTitle() should return false with no title' );
{
	ok(
		!restrictTitle( { title => 'bad title' } ),
		'... should return false if title contains a space'
	);
	like( $errors, qr/htmlcode.+invalid characters/, '... logging an error' );

}
ok(
	restrictTitle(
		{ title => join( '', ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 ) ) }
	),
	'... should return true if title contains only alphanumeric characters'
);

sub AUTOLOAD
{
	return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::Node::htmlcode::$AUTOLOAD";

	if ( defined &{$sub} )
	{
		*{$AUTOLOAD} = \&{$sub};
		goto &{$sub};
	}
}
