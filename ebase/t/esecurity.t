#!/usr/bin/perl -w

use strict;
use vars qw( $AUTOLOAD );

BEGIN {
	chdir 't' if -d 't';
	use lib '../blib/lib', '..', 'lib/';
}

use Test::More tests => 11;

use_ok( 'Everything::Security' );

# inheritPermissions()
is( inheritPermissions('----', 'rwxd'), '----', 
	'inheritPermissions() should not modify uninheritable permissions' );
is( inheritPermissions('i-i-', 'rwxd'), 'r-x-', 
	'... and should inherit the inheritable' );

my $warn;
local $SIG{__WARN__} = sub {
	$warn .= join('', @_);
};

ok( !inheritPermissions('---', '----'), 
	'... should fail with permission length mismatch' ); 
like( $warn, qr/permission length mismatch/i, '... and warn about it' );

# checkPermissions()
$warn = '';
ok( ! checkPermissions('rwx-'),
	'check() should return false unless modes are passed' );
is( $warn, '', '... and should not warn' );

ok( checkPermissions('rwxd', 'rw'),
	'... should return true if op is permitted' );
ok( ! checkPermissions('rwxd', 'rwxdc'), '... and false if op is prohibited' );
ok( ! checkPermissions('', 'r'), '... and false if no perms are present' );
ok( ! checkPermissions('i', ''), '... and false if no modes are present' );

sub AUTOLOAD {
    return if $AUTOLOAD =~ /DESTROY$/;

	no strict 'refs';
	$AUTOLOAD =~ s/^main:://;

	my $sub = "Everything::Security::$AUTOLOAD";

	if (defined &{ $sub }) {
		*{ $AUTOLOAD } = \&{ $sub };
		goto &{ $sub };
	}
}
