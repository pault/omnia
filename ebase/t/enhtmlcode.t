#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD $errors );

BEGIN {
	chdir 't' if -d 't';
	unshift @INC, '../blib/lib', 'lib', '..';
}

use Test::More tests => 5;

use_ok( 'Everything::Node::htmlcode' );

# restrictTitle()
ok( ! restrictTitle({}), 'restrictTitle() should return false with no title' );
{
	ok( ! restrictTitle({ title => 'bad title' }),
		'... should return false if title contains a space' );
	like( $errors, qr/htmlcode.+invalid characters/, '... logging an error' );

}
ok( restrictTitle({ title => join('', ( 'a' .. 'z', 'A' .. 'Z', 0 .. 9 )) }),
	'... should return true if title contains only alphanumeric characters' );

sub AUTOLOAD {
    return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::Node::htmlcode::$AUTOLOAD";

	if (defined &{ $sub }) {
		*{ $AUTOLOAD } = \&{ $sub };
		goto &{ $sub };
	}
}

sub Everything::logErrors {
	$main::errors = join(' ', @_);
}
